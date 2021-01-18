package eu.xenit.docker.solr.test;

import static io.restassured.RestAssured.given;
import static io.restassured.http.ContentType.JSON;
import static java.lang.Thread.sleep;
import static org.hamcrest.CoreMatchers.containsString;
import static org.hamcrest.Matchers.greaterThan;
import static org.junit.Assert.assertThat;

import io.restassured.RestAssured;
import io.restassured.authentication.PreemptiveBasicAuthScheme;
import io.restassured.builder.RequestSpecBuilder;
import io.restassured.parsing.Parser;
import io.restassured.response.Response;
import io.restassured.specification.RequestSpecification;
import org.junit.BeforeClass;
import org.junit.Test;

public class SolrSmokeTests {
    static RequestSpecification spec;
    static RequestSpecification specShardedSolr1;
    static RequestSpecification specShardedSolr2;
    static RequestSpecification specTelemetry;
    static boolean telemetry = false;

    @BeforeClass
    public static void setup() {

        String basePath = "/alfresco";
        String basePathSolr = "solr/admin/cores";
        String basePathSolrTelemetry = "solr/alfresco/metrics";
        telemetry = Boolean.valueOf(System.getProperty("telemetry"));
        if("solr4".equals(System.getProperty("flavor"))) {
            basePathSolr = "solr4/admin/cores";
            basePathSolrTelemetry = "solr4/alfresco/metrics";	    
	}
        String host = System.getProperty("alfresco.host");
        String solrHost = System.getProperty("solr.host");
        String solr1 = System.getProperty("solr1.host");
        String solr2 = System.getProperty("solr2.host");
        int port = Integer.parseInt(System.getProperty("alfresco.tcp.8080"));
        int solrPort = 0;
	try {
	    solrPort = Integer.parseInt(System.getProperty("solr.tcp.8080"));
	} catch(NumberFormatException e) {
	    System.out.println("Solr port 8080 is not exposed, probably ssl is enabled");
	}
        int portShardedSolr1 = ((solr1!=null)?Integer.parseInt(System.getProperty("solr1.tcp.8080")):-1);
        int portShardedSolr2 = ((solr1!=null)?Integer.parseInt(System.getProperty("solr2.tcp.8080")):-1);

        System.out.println("basePath=" + basePath + " and basePathSolr=" + basePathSolr +
                " and host=" + host + " and solr1=" + solr1 + " and solr2=" + solr2 +
                " and port=" + port + " and portShardedSolr1=" + portShardedSolr1 +
                " and portShardedSolr2=" + portShardedSolr2 + " and telemetry=" + telemetry);

        String baseURI = "http://" + host;
        String baseURISolr = "http://" + solrHost;
        String baseURIShardedSolr1 = "http://" + solr1;
        String baseURIShardedSolr2 = "http://" + solr2;

        PreemptiveBasicAuthScheme authScheme = new PreemptiveBasicAuthScheme();
        authScheme.setUserName("admin");
        authScheme.setPassword("admin");
        RestAssured.defaultParser = Parser.JSON;

        spec = new RequestSpecBuilder()
                .setBaseUri(baseURI)
                .setPort(port)
                .setBasePath(basePath)
                .setAuth(authScheme)
                .build();

        if(solr1 != null) {
            specShardedSolr1 = new RequestSpecBuilder()
                    .setBaseUri(baseURIShardedSolr1)
                    .setPort(portShardedSolr1)
                    .setBasePath(basePathSolr)
                    .addParam("action","STATUS")
                    .addParam("wt","json")
                    .build();
            specShardedSolr2 = new RequestSpecBuilder()
                    .setBaseUri(baseURIShardedSolr2)
                    .setPort(portShardedSolr2)
                    .setBasePath(basePathSolr)
                    .addParam("action","STATUS")
                    .addParam("wt","json")
                    .build();
        } else {
            specShardedSolr1 = null;
            specShardedSolr2 = null;
        }

        if(telemetry) {
            specTelemetry = new RequestSpecBuilder()
                    .setBaseUri(baseURISolr)
                    .setPort(solrPort)
                    .setBasePath(basePathSolrTelemetry)
                    .addParam("wt","dummy")
                    .build();
            System.out.println("baseURISolr=" + baseURISolr + " and solrPort=" + solrPort + " and path=" + basePathSolrTelemetry);
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
    public void testSearch(){
        String flavor = System.getProperty("flavor");
        System.out.println("flavor=" + flavor);
        String response;

        if("solr4".equals(flavor) || "solr1".equals(flavor)) {
            System.out.println("will use slingshot webscript");
            String urlSearch = "/s/slingshot/search?term=pdf*";

            response = given()
                    .spec(spec)
                    .when()
                    .get(urlSearch)
                    .then()
                    .statusCode(200)
                    .extract()
                    .path("totalRecords")
                    .toString();
        } else {
            System.out.println("will use api call");
            String urlSearch = "/api/-default-/public/search/versions/1/search";
            // simple json, no need for an additional library
            // templates don't work with afts, fields to search into need to be specified
            String requestParams = "{ \"query\": { \"query\": \"cm:name:pdf*\" } }";
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
        }
        System.out.println("response=" + response);
        assertThat(Integer.parseInt(response), greaterThan(0));
    }

    @Test
    public void TestShards() {
        if(specShardedSolr1 != null) {
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
            assertThat(docs0,greaterThan(50));
            assertThat(docs1,greaterThan(50));
            assertThat(docs2,greaterThan(50));
        }
    }

    @Test
    public void testTelemetryEndpoint() {
        if(telemetry) {
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
}
