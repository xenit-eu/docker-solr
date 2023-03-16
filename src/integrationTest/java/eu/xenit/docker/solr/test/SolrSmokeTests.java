package eu.xenit.docker.solr.test;

import io.restassured.RestAssured;
import io.restassured.authentication.PreemptiveBasicAuthScheme;
import io.restassured.builder.RequestSpecBuilder;
import io.restassured.config.RestAssuredConfig;
import io.restassured.config.SSLConfig;
import io.restassured.parsing.Parser;
import io.restassured.specification.RequestSpecification;
import org.apache.http.conn.ssl.AllowAllHostnameVerifier;
import org.apache.http.conn.ssl.SSLSocketFactory;
import org.junit.BeforeClass;
import org.junit.Test;

import java.io.FileInputStream;
import java.security.KeyManagementException;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.UnrecoverableKeyException;

import static io.restassured.RestAssured.given;
import static io.restassured.http.ContentType.JSON;
import static java.lang.Thread.sleep;
import static org.hamcrest.CoreMatchers.containsString;
import static org.hamcrest.Matchers.greaterThan;
import static org.junit.Assert.assertThat;

public class SolrSmokeTests {

    static RequestSpecification spec;
    static RequestSpecification specShardedSolr1;
    static RequestSpecification specShardedSolr2;
    static RequestSpecification specTelemetry;
    static RequestSpecification specActuators;
    static boolean telemetry = false;
    static boolean actuators = false;
    static boolean use_ssl = false;

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

    @BeforeClass
    public static void setup()
            throws UnrecoverableKeyException, NoSuchAlgorithmException, KeyStoreException,
            KeyManagementException {

        String basePath = "/alfresco";
        String basePathSolr = "solr/admin/cores";
        String basePathSolrTelemetry = "solr/alfresco/metrics";
        telemetry = Boolean.valueOf(System.getProperty("telemetry"));
        String basePathSolrActuators = "solr/alfresco/xenit/actuators/readiness";
        actuators = Boolean.valueOf(System.getProperty("actuators"));

        use_ssl = (System.getProperty("use_ssl") != null) ? Boolean.parseBoolean(System.getProperty("use_ssl")) : false;

        String host = System.getProperty("alfresco.host");
        String solrHost = System.getProperty("solr.host");
        String solr1 = System.getProperty("solr1.host");
        String solr2 = System.getProperty("solr2.host");
        int port = Integer.parseInt(System.getProperty("alfresco.tcp.8080"));
        int solrPort;
        int portShardedSolr1 = -1;
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
                " and portShardedSolr2=" + portShardedSolr2 + " and telemetry=" + telemetry + " and actuators="
                + actuators);

        String protocol = "http://";
        // Alfresco is always http
        String baseURI = protocol + host;
        if (use_ssl) {
            protocol = "https://";
        }
        String baseURISolr = protocol + solrHost;
        String baseURIShardedSolr1 = protocol + solr1;
        String baseURIShardedSolr2 = protocol + solr2;

        PreemptiveBasicAuthScheme authScheme = new PreemptiveBasicAuthScheme();
        authScheme.setUserName("admin");
        authScheme.setPassword("admin");
        RestAssured.defaultParser = Parser.JSON;

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
        spec = new RequestSpecBuilder()
                .setBaseUri(baseURI)
                .setPort(port)
                .setBasePath(basePath)
                .setAuth(authScheme)
                .build();

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

        if (telemetry) {
            specTelemetry = new RequestSpecBuilder()
                    .setBaseUri(baseURISolr)
                    .setPort(solrPort)
                    .setBasePath(basePathSolrTelemetry)
                    .addParam("wt", "dummy")
                    .build();
            System.out.println(
                    "baseURISolr=" + baseURISolr + " and solrPort=" + solrPort + " and path=" + basePathSolrTelemetry);
        }

        if (actuators) {
            specActuators = new RequestSpecBuilder()
                    .setBaseUri(baseURISolr)
                    .setPort(solrPort)
                    .setBasePath(basePathSolrActuators)
                    .build();
            System.out.println(
                    "baseURISolr=" + baseURISolr + " and solrPort=" + solrPort + " and path=" + basePathSolrActuators);
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
    public void testSearch() {
        String flavor = System.getProperty("flavor");
        System.out.println("flavor=" + flavor);
        String response;

        System.out.println("will use api call");
        String urlSearch = "/api/-default-/public/search/versions/1/search";
        // simple json, no need for an additional library
        // templates don't work with afts, fields to search into need to be specified
        String requestParams = "{ \"query\": { \"query\": \"cm:name:xml*\" } }";
        response = given()
                .spec(spec)
                .when()
                .header("Content-Type", "application/json")
                .body(requestParams)
                .post(urlSearch)
                .then()
                .statusCode(200)
                .extract()
                .path("list.pagination.totalItems")
                .toString();

        System.out.println("response=" + response);
        assertThat(Integer.parseInt(response), greaterThan(0));
    }

    @Test
    public void TestShards() {
        if (specShardedSolr1 != null) {
            Integer docs0 = given()
                    .spec(specShardedSolr1)
                    .contentType("application/json")
                    .when()
                    .get()
                    .then()
                    .statusCode(200)
                    .contentType(JSON)
                    .extract().path("status.alfresco-0.index.numDocs");
            Integer docs1 = given()
                    .spec(specShardedSolr1)
                    .contentType("application/json")
                    .when()
                    .get()
                    .then()
                    .statusCode(200)
                    .contentType(JSON)
                    .extract().path("status.alfresco-1.index.numDocs");
            Integer docs2 = given()
                    .spec(specShardedSolr2)
                    .contentType("application/json")
                    .when()
                    .get()
                    .then()
                    .statusCode(200)
                    .contentType(JSON)
                    .extract().path("status.alfresco-2.index.numDocs");
            assertThat(docs0, greaterThan(50));
            assertThat(docs1, greaterThan(50));
            assertThat(docs2, greaterThan(50));
        }
    }

    @Test
    public void testTelemetryEndpoint() {
        if (telemetry) {
            String response = given()
                    .spec(specTelemetry)
                    .when()
                    .get()
                    .then()
                    .statusCode(200)
                    .body(containsString("alfresco_nodes"))
                    .toString();
        }
    }

    @Test
    public void testActuatorsEndpoint() {
        if (actuators) {
            String response = given()
                    .spec(specActuators)
                    .when()
                    .get()
                    .then()
                    .statusCode(200)
                    .body(containsString("UP"))
                    .toString();
        }
    }
}
