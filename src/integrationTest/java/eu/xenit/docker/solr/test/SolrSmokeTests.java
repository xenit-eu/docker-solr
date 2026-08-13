package eu.xenit.docker.solr.test;

import io.restassured.RestAssured;
import io.restassured.authentication.PreemptiveBasicAuthScheme;
import io.restassured.builder.RequestSpecBuilder;
import io.restassured.config.RestAssuredConfig;
import io.restassured.config.SSLConfig;
import io.restassured.parsing.Parser;
import io.restassured.response.Response;
import io.restassured.specification.RequestSpecification;
import org.apache.http.conn.ssl.AllowAllHostnameVerifier;
import org.apache.http.conn.ssl.SSLSocketFactory;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import org.awaitility.core.ConditionTimeoutException;

import java.io.FileInputStream;
import java.security.KeyManagementException;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.UnrecoverableKeyException;
import java.util.concurrent.TimeUnit;
import java.util.function.Supplier;

import static io.restassured.RestAssured.given;
import static io.restassured.http.ContentType.JSON;
import static org.awaitility.Awaitility.await;
import static org.hamcrest.CoreMatchers.containsString;
import static org.junit.jupiter.api.Assertions.assertTrue;

public class SolrSmokeTests {

    private static final String SEARCH_URL = "/api/-default-/public/search/versions/1/search";
    // simple json, no need for an additional library
    // templates don't work with afts, fields to search into need to be specified
    private static final String SEARCH_BODY = "{ \"query\": { \"query\": \"cm:name:xml*\" } }";

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

    @BeforeAll
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
        awaitTracking();
    }

    /**
     * Solr tracks Alfresco in the background, so the smoke tests only become meaningful once the
     * first content has been indexed.
     */
    private static void awaitTracking() {
        try {
            await().atMost(5, TimeUnit.MINUTES)
                    .pollInterval(2, TimeUnit.SECONDS)
                    // tracking has not started yet, so the endpoints may still error out
                    .ignoreExceptions()
                    .until(SolrSmokeTests::isTracked);
        } catch (ConditionTimeoutException e) {
            // Deliberately not failing here: the assertions below report what is actually
            // missing, which beats a bare timeout.
            System.out.println("Timed out waiting for Solr to track content, running tests anyway.");
            reportReadiness();
        }
    }

    /**
     * "Expected status code 200 but was 503" does not say which component is unhealthy, and by the
     * time an assertion fails we no longer know which of the awaited conditions held. The readiness
     * bodies usually name the culprit, so dump them once when the wait gives up.
     */
    private static void reportReadiness() {
        System.out.println("  search hits: " + attempt(SolrSmokeTests::searchHits));
        if (telemetry) {
            System.out.println("  telemetry: " + probe(specTelemetry));
        }
        if (actuators) {
            System.out.println("  actuators: " + probe(specActuators));
        }
        if (specShardedSolr1 != null) {
            System.out.println("  alfresco-0 docs: " + attempt(() -> coreDocs(specShardedSolr1, "alfresco-0")));
            System.out.println("  alfresco-1 docs: " + attempt(() -> coreDocs(specShardedSolr1, "alfresco-1")));
            System.out.println("  alfresco-2 docs: " + attempt(() -> coreDocs(specShardedSolr2, "alfresco-2")));
        }
    }

    private static String probe(RequestSpecification endpointSpec) {
        try {
            Response response = given().spec(endpointSpec).when().get();
            String body = response.asString();
            if (body != null && body.length() > 500) {
                body = body.substring(0, 500) + " ...(truncated)";
            }
            return "HTTP " + response.statusCode() + " body=" + body;
        } catch (Exception e) {
            return "request failed: " + e;
        }
    }

    private static String attempt(Supplier<Integer> value) {
        try {
            return String.valueOf(value.get());
        } catch (Exception e) {
            return "unavailable: " + e;
        }
    }

    private static boolean isTracked() {
        if (searchHits() <= 0) {
            return false;
        }
        // These lag behind tracking: solr answers searches before the readiness probe flips to UP.
        if (telemetry && !endpointServes(specTelemetry, "alfresco_nodes")) {
            return false;
        }
        if (actuators && !endpointServes(specActuators, "UP")) {
            return false;
        }
        if (specShardedSolr1 == null) {
            return true;
        }
        return coreDocs(specShardedSolr1, "alfresco-0") > 50
                && coreDocs(specShardedSolr1, "alfresco-1") > 50
                && coreDocs(specShardedSolr2, "alfresco-2") > 50;
    }

    private static boolean endpointServes(RequestSpecification endpointSpec, String expected) {
        Response response = given().spec(endpointSpec).when().get();
        return response.statusCode() == 200 && response.asString().contains(expected);
    }

    private static int searchHits() {
        Object totalItems = given()
                .spec(spec)
                .when()
                .header("Content-Type", "application/json")
                .body(SEARCH_BODY)
                .post(SEARCH_URL)
                .then()
                .statusCode(200)
                .extract()
                .path("list.pagination.totalItems");

        return totalItems == null ? 0 : Integer.parseInt(totalItems.toString());
    }

    private static int coreDocs(RequestSpecification solrSpec, String core) {
        Integer docs = given()
                .spec(solrSpec)
                .contentType("application/json")
                .when()
                .get()
                .then()
                .statusCode(200)
                .contentType(JSON)
                .extract().path("status." + core + ".index.numDocs");

        // the core is absent from the status response until it has been created
        return docs == null ? 0 : docs;
    }

    @Test
    public void testSearch() {
        String flavor = System.getProperty("flavor");
        System.out.println("flavor=" + flavor);

        int totalItems = searchHits();

        System.out.println("response=" + totalItems);
        assertTrue(totalItems > 0, "Response list.pagination.totalItems > 0");
    }

    @Test
    public void TestShards() {
        if (specShardedSolr1 != null) {
            int docs0 = coreDocs(specShardedSolr1, "alfresco-0");
            int docs1 = coreDocs(specShardedSolr1, "alfresco-1");
            int docs2 = coreDocs(specShardedSolr2, "alfresco-2");
            assertTrue(docs0 > 50, "docs0 is greater than 50");
            assertTrue(docs1 > 50, "docs1 is greater than 50");
            assertTrue(docs2 > 50, "docs2 is greater than 50");
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
