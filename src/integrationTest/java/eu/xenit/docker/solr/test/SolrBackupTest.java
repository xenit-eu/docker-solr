package eu.xenit.docker.solr.test;

import com.amazonaws.ClientConfiguration;
import com.amazonaws.Protocol;
import com.amazonaws.auth.AWSStaticCredentialsProvider;
import com.amazonaws.auth.BasicAWSCredentials;
import com.amazonaws.client.builder.AwsClientBuilder;
import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3ClientBuilder;
import com.amazonaws.services.s3.model.S3ObjectSummary;
import io.restassured.RestAssured;
import io.restassured.authentication.PreemptiveBasicAuthScheme;
import io.restassured.builder.RequestSpecBuilder;
import io.restassured.config.RestAssuredConfig;
import io.restassured.config.SSLConfig;
import io.restassured.parsing.Parser;
import io.restassured.specification.RequestSpecification;
import org.apache.http.conn.ssl.AllowAllHostnameVerifier;
import org.apache.http.conn.ssl.SSLSocketFactory;
import org.awaitility.Awaitility;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Order;
import org.junit.jupiter.api.Test;

import java.io.FileInputStream;
import java.security.*;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.TimeUnit;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

import static io.restassured.RestAssured.given;
import static java.lang.Thread.sleep;
import static org.awaitility.Awaitility.await;
import static org.junit.jupiter.api.Assertions.assertEquals;

public class SolrBackupTest {
    static AmazonS3 s3Client;
    static RequestSpecification specShardedSolr1;
    static RequestSpecification specShardedSolr2;
    static RequestSpecification backupRequestSpec;
    static RequestSpecification backupDetailsRequestSpec;
    static RequestSpecification restoreFixedSnapshotRequestSpec;
    static RequestSpecification restoreStatusRequestSpec;
    static RequestSpecification restoreRequestSpec;
    static String solr1;
    static String baseURIShardedSolr1;
    static String baseURISolr;
    static int solrPort;
    static int portShardedSolr1 = -1;
    static boolean use_ssl = false;
    static final String BUCKET = "bucket";
    static final String basePathSolrBackup = "solr/alfresco/replication";

    private static KeyStore loadKeyStore(String path, char[] password, String storeType) {
        KeyStore keyStore;
        try {
            keyStore = KeyStore.getInstance(storeType);
            keyStore.load(new FileInputStream(path), password);
        } catch (Exception ex) {
            throw new RuntimeException("Error while extracting the keystore", ex);
        }
        return keyStore;
    }

    private static RestAssuredConfig ssl_config(
            String keyStorePath,
            String keyStorePass,
            String keyStoreType,
            String trustStorePath,
            String trustStorePass,
            String trustStoreType)
            throws UnrecoverableKeyException, NoSuchAlgorithmException, KeyStoreException,
            KeyManagementException {

        KeyStore keyStore = loadKeyStore(keyStorePath, keyStorePass.toCharArray(), keyStoreType);
        SSLSocketFactory clientAuthFactory = new SSLSocketFactory(keyStore, keyStorePass);
        if (null != trustStorePath) {
            KeyStore trustStore = loadKeyStore(trustStorePath, trustStorePass.toCharArray(), trustStoreType);
            clientAuthFactory = new SSLSocketFactory(keyStore, keyStorePass, trustStore);
        }
        clientAuthFactory.setHostnameVerifier(new AllowAllHostnameVerifier());

        SSLConfig sslConfig = RestAssuredConfig.config().getSSLConfig().with().sslSocketFactory(clientAuthFactory);
        return RestAssured.config().sslConfig(sslConfig);
    }



    @BeforeAll
    public static void setup()
            throws UnrecoverableKeyException, NoSuchAlgorithmException, KeyStoreException,
            KeyManagementException {

        String basePath = "/alfresco";
        String basePathSolr = "solr/admin/cores";

        use_ssl = (System.getProperty("use_ssl") != null) ? Boolean.parseBoolean(System.getProperty("use_ssl")) : false;

        String host = System.getProperty("alfresco.host");
        String solrHost = System.getProperty("solr.host");
        solr1 = System.getProperty("solr1.host");
        String solr2 = System.getProperty("solr2.host");
        int port = Integer.parseInt(System.getProperty("alfresco.tcp.8080"));
        portShardedSolr1 = -1;
        int portShardedSolr2 = -1;

        if (solr1 == null) {
            if (System.getProperty("solr.tcp.8080") == null) {
                solrPort = Integer.parseInt(System.getProperty("solr.tcp.8443"));
                use_ssl = true;
            } else {
                solrPort = Integer.parseInt(System.getProperty("solr.tcp.8080"));
            }
        } else {
            if (use_ssl) {
                portShardedSolr1 = Integer.parseInt(System.getProperty("solr1.tcp.8443"));
                portShardedSolr2 = Integer.parseInt(System.getProperty("solr2.tcp.8443"));
            } else {
                portShardedSolr1 = Integer.parseInt(System.getProperty("solr1.tcp.8080"));
                portShardedSolr2 = Integer.parseInt(System.getProperty("solr2.tcp.8080"));
            }

            solrPort = portShardedSolr1;
        }

        System.out.println("basePath=" + basePath + " and basePathSolr=" + basePathSolr +
                " and host=" + host + " and solr1=" + solr1 + " and solr2=" + solr2 +
                " and port=" + port + " and portShardedSolr1=" + portShardedSolr1 +
                " and portShardedSolr2=" + portShardedSolr2);

        String protocol = "http://";
        // Alfresco is always http
        String baseURI = protocol + host;
        if (use_ssl) {
            protocol = "https://";
        }
        baseURISolr = protocol + solrHost;
        baseURIShardedSolr1 = protocol + solr1;
        String baseURIShardedSolr2 = protocol + solr2;

        PreemptiveBasicAuthScheme authScheme = new PreemptiveBasicAuthScheme();
        authScheme.setUserName("admin");
        authScheme.setPassword("admin");
        RestAssured.defaultParser = Parser.JSON;

        s3Client = createInternalClient("us-east-1",
                "http://localhost:4566",
                "access_key",
                "secret_key");

        if (solr1 != null) {
            specShardedSolr1 = new RequestSpecBuilder()
                    .setBaseUri(baseURIShardedSolr1)
                    .setPort(portShardedSolr1)
                    .setBasePath(basePathSolr)
                    .addParam("action", "STATUS")
                    .addParam("wt", "json")
                    .build();
            specShardedSolr2 = new RequestSpecBuilder()
                    .setBaseUri(baseURIShardedSolr2)
                    .setPort(portShardedSolr2)
                    .setBasePath(basePathSolr)
                    .addParam("action", "STATUS")
                    .addParam("wt", "json")
                    .build();
        } else {
            specShardedSolr1 = null;
            specShardedSolr2 = null;
        }

        System.out.println("basePath=" + basePath + " and host=" + host + " and port=" + port);

        if (use_ssl) {
            RestAssured.config = ssl_config(
                    System.getProperty("keystore"),
                    "kT9X6oe68t",
                    "JCEKS",
                    System.getProperty("truststore"),
                    "kT9X6oe68t",
                    "JCEKS"
            );
        }

        if (solr1 != null) {
            specShardedSolr1 = new RequestSpecBuilder()
                    .setBaseUri(baseURIShardedSolr1)
                    .setPort(portShardedSolr1)
                    .setBasePath(basePathSolr)
                    .addParam("action", "STATUS")
                    .addParam("wt", "json")
                    .build();
            // Set requests as Sharded!
            backupRequestSpec = new RequestSpecBuilder()
                    .setBaseUri(baseURIShardedSolr1)
                    .setPort(portShardedSolr1)
                    .setBasePath(basePathSolrBackup)
                    .addParam("command", "backup")
                    .addParam("repository", "s3")
                    .addParam("numberToKeep", "2")
                    .addParam("location", "s3://bucket/opt/alfresco-search-services/data/solr6Backup/")
                    .addParam("wt", "json")
                    .build();
            backupDetailsRequestSpec = new RequestSpecBuilder()
                    .setBaseUri(baseURIShardedSolr1)
                    .setPort(portShardedSolr1)
                    .setBasePath(basePathSolrBackup)
                    .addParam("command", "details")
                    .addParam("wt", "json")
                    .build();
            restoreFixedSnapshotRequestSpec = new RequestSpecBuilder()
                    .setBaseUri(baseURIShardedSolr1)
                    .setPort(portShardedSolr1)
                    .setBasePath(basePathSolrBackup)
                    .addParam("command", "restore")
                    .addParam("repository", "s3")
                    .addParam("location", "s3://bucket/opt/alfresco-search-services/data/solr6Backup/")
                    .addParam("name", "my-alfresco-backup-20251006")
                    .build();
            restoreStatusRequestSpec = new RequestSpecBuilder()
                    .setBaseUri(baseURIShardedSolr1)
                    .setPort(portShardedSolr1)
                    .setBasePath(basePathSolrBackup)
                    .addParam("command", "restorestatus")
                    .addParam("wt", "json")
                    .build();
        } else{
            backupRequestSpec = new RequestSpecBuilder()
                    .setBaseUri(baseURISolr)
                    .setPort(solrPort)
                    .setBasePath(basePathSolrBackup)
                    .addParam("command", "backup")
                    .addParam("repository", "s3")
                    .addParam("numberToKeep", "2")
                    .addParam("location", "s3://bucket/opt/alfresco-search-services/data/solr6Backup/")
                    .addParam("wt", "json")
                    .build();
            backupDetailsRequestSpec = new RequestSpecBuilder()
                    .setBaseUri(baseURISolr)
                    .setPort(solrPort)
                    .setBasePath(basePathSolrBackup)
                    .addParam("command", "details")
                    .addParam("wt", "json")
                    .build();
            restoreFixedSnapshotRequestSpec = new RequestSpecBuilder()
                    .setBaseUri(baseURISolr)
                    .setPort(solrPort)
                    .setBasePath(basePathSolrBackup)
                    .addParam("command", "restore")
                    .addParam("repository", "s3")
                    .addParam("location", "s3://bucket/opt/alfresco-search-services/data/solr6Backup/")
                    .addParam("name", "my-alfresco-backup-20251006")
                    .build();
            restoreStatusRequestSpec = new RequestSpecBuilder()
                    .setBaseUri(baseURISolr)
                    .setPort(solrPort)
                    .setBasePath(basePathSolrBackup)
                    .addParam("command", "restorestatus")
                    .addParam("wt", "json")
                    .build();
        }
        // wait for solr to track
        long sleepTime = 30000;
        try {
            sleep(sleepTime);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }

    @Test
    @Order(3)
    void testRestorePointInTimeScriptEndpoint() {
        System.out.println("Restore triggered at solr-startup after health-check succeeded, will wait maximum 3 minutes");
        // Check logs for restore at startup... (Solr doesnt remember by the time we reach our test).
        // Retrigger a restore from the backup
        String responseBody = given()
                .spec(restoreFixedSnapshotRequestSpec)
                .when()
                .get()
                .then()
                .statusCode(200)
                .extract()
                .body() // Extract the whole body
                .asString(); // as a simple string
        long startTime = System.currentTimeMillis();
        await().atMost(180, TimeUnit.SECONDS)
                .pollInterval(1, TimeUnit.SECONDS).until(() -> {
                    String status = given()
                            .spec(restoreStatusRequestSpec)
                            .when()
                            .get()
                            .then()
                            .statusCode(200)
                            .extract()
                            .path("restorestatus.status");
                    System.out.println("elapsed = " + (System.currentTimeMillis() - startTime) + "with status= " + status);
                    return "success".equals(status);
                });
    }

    @Test
    @Order(2)
    void testRestoreToLatestBackup() {
        // SOLR in Standalone mode, there is no API command to list or fetch backups.
        // Fetch all fileNames from our Localstack S3 bucket
        // First wait 10 seconds so backups made in test 1 are available...
        Awaitility.await()
                .timeout(15, TimeUnit.SECONDS)
                .pollDelay(8, TimeUnit.SECONDS)
                .untilAsserted(() -> Assertions.assertTrue(true));
        String lastSnapshotName = returnLastSnapshotName();
        // Set assert to check if not null / empty.

        System.out.println("Found latest snapshot: " + lastSnapshotName);


        if (solr1 != null) {
            restoreRequestSpec = new RequestSpecBuilder()
                    .setBaseUri(baseURIShardedSolr1)
                    .setPort(portShardedSolr1)
                    .setBasePath(basePathSolrBackup)
                    .addParam("command", "restore")
                    .addParam("repository", "s3")
                    .addParam("location", "s3://bucket/opt/alfresco-search-services/data/solr6Backup/")
                    .addParam("name", lastSnapshotName)
                    .build();
        } else {
            restoreRequestSpec = new RequestSpecBuilder()
                    .setBaseUri(baseURISolr)
                    .setPort(solrPort)
                    .setBasePath(basePathSolrBackup)
                    .addParam("command", "restore")
                    .addParam("repository", "s3")
                    .addParam("location", "s3://bucket/opt/alfresco-search-services/data/solr6Backup/")
                    .addParam("name", lastSnapshotName)
                    .build();
        }

        System.out.println("Restore triggered, will wait maximum 3 minutes");
        given()
                .spec(restoreRequestSpec)
                .when()
                .get()
                .then()
                .statusCode(200);
        System.out.println("Restore triggered, will wait maximum 3 minutes");
        long startTime = System.currentTimeMillis();
        await().atMost(180, TimeUnit.SECONDS)
                .pollInterval(1, TimeUnit.SECONDS).until(() -> {
                    String status = given()
                            .spec(restoreStatusRequestSpec)
                            .when()
                            .get()
                            .then()
                            .statusCode(200)
                            .extract()
                            .path("restorestatus.status");
                    System.out.println("elapsed = " + (System.currentTimeMillis() - startTime) + "with status= " + status);
                    return "success".equals(status);
                });
    }
    @Test
    @Order(1)
    void testBackupWithNumberToLiveEndpoint() {
        validateSnapshotCount(0);
        triggerBackupAndWaitForCompletion(1, backupRequestSpec);

        validateSnapshotCount(1);
        triggerBackupAndWaitForCompletion(2, backupRequestSpec);

        validateSnapshotCount(2);
        triggerBackupAndWaitForCompletion(3, backupRequestSpec);
        validateSnapshotCount(2);
    }


    void validateSnapshotCount(long count) {
        await().atMost(180, TimeUnit.SECONDS)
                .until(() -> s3Client.listObjects(BUCKET)
                        .getObjectSummaries()
                        .stream()
                        .filter(s3ObjectSummary -> s3ObjectSummary.getSize() == 0
                                && s3ObjectSummary.getKey().contains("snapshot"))
                        .count() == count);

    }
    String returnLastSnapshotName() {
        List<S3ObjectSummary> snapshots = s3Client.listObjects(BUCKET)
                        .getObjectSummaries()
                        .stream()
                        .filter(s3ObjectSummary -> s3ObjectSummary.getKey().contains("snapshot"))
                        .collect(Collectors.toList());

        snapshots.forEach(s3ObjectSummary -> System.out.println("Found snapshot: " + s3ObjectSummary.getKey()));

        String latestSnapshot = null;
        if (snapshots != null && !snapshots.isEmpty()) {
            Optional<S3ObjectSummary> latestSnapshotOpt = snapshots.stream()
                    // Sort using the lastModified date of each S3 object
                    .max(Comparator.comparing(S3ObjectSummary::getLastModified));

            if (latestSnapshotOpt.isPresent()) {
                latestSnapshot = latestSnapshotOpt.get().getKey();
            }
        }

        Pattern pattern = Pattern.compile("snapshot\\.(.*?)/");
        Matcher matcher = pattern.matcher(latestSnapshot);
        return matcher.find() ? matcher.group(1) : null;
    }
    private void triggerBackupAndWaitForCompletion(int count, RequestSpecification solrBackupRequestSpec) {
        String status = given()
                .spec(solrBackupRequestSpec)
                .when()
                .get()
                .then()
                .statusCode(200)
                .extract()
                .path("status");
        assertEquals("OK", status);
        System.out.println("Solr backup triggered" + (count == 0 ? "" : count + " time ") + ", will wait maximum 9 minutes");
        long startTime = System.currentTimeMillis();
        await().atMost(540, TimeUnit.SECONDS)
                .pollInterval(1, TimeUnit.SECONDS)
                .until(() -> {
                    Object backup = given()
                            .spec(backupDetailsRequestSpec)
                            .when()
                            .get()
                            .then()
                            .statusCode(200)
                            .extract()
                            .path("details.backup");
                    System.out.println("elapsed = " + (System.currentTimeMillis() - startTime));
                    return backup != null;
                });
    }

    private static AmazonS3 createInternalClient(
                String region, String endpoint, String accessKey, String secretKey) {
        ClientConfiguration clientConfig = new ClientConfiguration().withProtocol(Protocol.HTTPS);
        AmazonS3ClientBuilder clientBuilder = AmazonS3ClientBuilder.standard().withClientConfiguration(clientConfig);
        clientBuilder.withCredentials(new AWSStaticCredentialsProvider(new BasicAWSCredentials(accessKey, secretKey)));
        clientBuilder.setEndpointConfiguration(new AwsClientBuilder.EndpointConfiguration(endpoint, region));
        clientBuilder.withPathStyleAccessEnabled(true);
        return clientBuilder.build();
    }


}