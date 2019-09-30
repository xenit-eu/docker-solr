# Solr in Docker

## Images created

* [`alfresco-solr1`] = solr1 images, using tomcat
* [`alfresco-solr4`] = solr4 images, using tomcat
* [`alfresco-solr6`] = solr6 images (alfresco search services), using jetty

## Supported Tags

* [`:4.2`, `:4.2.8`,`:5.1`, `:5.1.4.1`] = minor, major, revision for solr1 and solr4
* [`:1.0.0`, `:1.1.1`, `:1.2.0`] = version of the alfresco search services used for solr6

## Overview

This is the repository building Solr Docker images.

All images are automatically built by [jenkins-2](https://jenkins-2.xenit.eu) and published to [hub.xenit.eu](https://hub.xenit.eu).

Community images are built by [Travis](https://travis-ci.org/xenit-eu/) and published to [docker hub](https://hub.docker.com/u/xenit).

## Example docker-compose files

Each time images are built, tests are automatically ran on containers started via docker-compose files.

If sharding is involved, then a valid license file which allows clustering is needed.

## Environment variables

There are several environment variables available to tweak the behaviour. The variables are read by an init script which further replaces them in the relevant files. Such relevant files include:

* solrcore.properties
* schema.xml
* server.xml (ports, ssl-related properties for tomcat-based images)
* solr.in.sh (ports, ssl-related properties, paths for jetty-based images)
* setenv.sh (JAVA_OPTS parameters for tomcat-based images)

solrcore.properties can be set via a generic mechanism by setting environment variables of the form
GLOBAL_WORKSPACE\_\<parameter\> for workspace store,
GLOBAL_ARCHIVE\_<\parameter\> for archive store,
GLOBAL\_\<parameter\> for all cores.

They can also be set via environment variables of the form JAVA_OPTS\_<ignored_key> where the value should be "-Dkey=value".

A subset of the properties have also dedicated environment variables e.g. ALFRESCO_ENABLE_TRACKING. Generic variables take precedence.

A subset of java variables have also dedicated environment variables e.g. JAVA_XMX. Generic variables take precedence.

Environment variables:

| Variable                    | solrcore.property variable | java variable                                                | Default                                                      | Comments |
| --------------------------- | --------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ | --------------------------- |
| SHARDING                    |                      |                                                              | false                                               | if true, configuration folders for shards will be created |
| NUM_SHARDS                  | shard.count / acl.shard.count |                                                              | 3 | solr6 / solr4 |
| NUM_NODES           |                  |                                                              | 2                                                        |  |
| NODE_INSTANCE                  |                         |                                                              | 1                                                   |  |
| TEMPLATE                  | alfresco.template |                                                              | rerank                                                   |  |
| REPLICATION_FACTOR              |                     |                                                              | 1                                                        |  |
| SHARD_IDS                   | shard.instance / acl.shard.instance |                                                              | 0,1                                     | loop over values to create config folders \\ solr6 / solr4 |
| SHARD_METHOD | shard.method | | DB_ID | solr6 only |
| SHARD_KEY | shard.key | | cm:creator | solr6 only |
| CORES_TO_TRACK | | | alfresco;archive | loop over values to create config folders \\ solr6 only |
| SOLR_DATA_DIR | | | /opt/alfresco-search-services/data/index | solr6 only |
| SOLR_MODEL_DIR | | | /opt/alfresco-search-services/data/model | solr6 only |
| SOLR_CONTENT_DIR | | | /opt/alfresco-search-services/data/contentstore | solr6 only |
| ALFRESCO_SOLR_SUGGESTER_ENABLED                     | solr.suggester.enabled |                                                              | true                                                | needs also changes to schema.xml, otherwise not correct. |
| ALFRESCO_SOLR_FACETABLE_CATEGORIES_ENABLED                     |                            |                                                              |                                                          | changes schema.xml |
| ALFRESCO_HOST        | alfresco.host              |                                                              | alfresco |  |
| ALFRESCO_PORT    | alfresco.port          |                                                              | 8080 |  |
| ALFRESCO_PORT_SSL | alfresco.port.ssl      |                                                              | 8443 |  |
| ALFRESCO_SSL | alfresco.secureComms | | https | changes also server.xml for tomcat-based images and solr.in.sh for jetty-based images |
| ALFRESCO_ENABLE_TRACKING | enable.alfresco.tracking    |                                                              | true | in the workspace core or shard |
| ALFRESCO_INDEX_CONTENT | alfresco.index.transformContent |                                                              | true | in the workspace core or shard |
| ALFRESCO_CORE_POOL_SIZE | alfresco.corePoolSize |  | 8 |  |
| ALFRESCO_DO_PERMISSION_CHECKS | alfresco.doPermissionChecks |  | true | post filtering of results still happens on Alfresco side |
| ARCHIVE_ENABLE_TRACKING | enable.alfresco.tracking |  | true | in the archive core |
| ARCHIVE_INDEX_CONTENT | alfresco.index.transformContent |                                                              | true | in the archive core |
| TOMCAT_PORT |  | -DTOMCAT_PORT | 8080 | solr1 and solr4 only; Warning: at the moment changing this is not possible in practice, because the healthcheck always uses 8080|
| TOMCAT_PORT_SSL | | -DTOMCAT_PORT_SSL | 8443 | solr1 and solr4 only |
| TOMCAT_AJP_PORT | | -DTOMCAT_AJP_PORT | 8009 | solr1 and solr4 only |
| TOMCAT_SERVER_PORT | | -DTOMCAT_SERVER_PORT | 8005 | solr1 and solr4 only |
| TOMCAT_MAX_HTTP_HEADER_SIZE | | -DTOMCAT_MAX_HTTP_HEADER_SIZE  or -DMAX_HTTP_HEADER_SIZE | 32768 | solr1 and solr4 only |
| TOMCAT_MAX_THREADS | | -DTOMCAT_MAX_THREADS or -DMAX_THREADS | 200 | solr1 and solr4 only |
| JETTY_PORT | |  | 8080 | solr6 only |
| JETTY_PORT_SSL | |  | 8443 | solr6 only |
| JAVA_XMX | | -Xmx | 2048M | |
| JAVA_XMS | | -Xms | 512M | |
| JMX_ENABLED | | -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.local.only=false -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.rmi.port=5000 -Dcom.sun.management.jmxremote.port=5000 -Djava.rmi.server.hostname=$JMX_RMI_HOST | false | |
| JMX_RMI_HOST | |  | 0.0.0.0 | |
| DEBUG | | -Xdebug -Xrunjdwp:transport=dt_socket, address=8000, server=y, suspend=n | false | |
| GLOBAL_WORKSPACE_\<variable\> | \<variable\> | | | for workspace core or shards |
| GLOBAL_ARCHIVE_\<variable\> | \<variable\> | | | for archive core |
| GLOBAL_\<variable\> | \<variable> | | |  |
| JAVA_OPTS_\<ignored_variable\>=\<value\> |  | \<value\> | | |
| SSL_KEY_STORE | | | ssl.repo.client.keystore | solr6 only |
| SSL_KEY_STORE_PASSWORD' | | | keystore | solr6 only |
| SSL_TRUST_STORE | | | ssl.repo.client.truststore | solr6 only |
| SSL_TRUST_STORE_PASSWORD | | | truststore | solr6 only |

## Docker-compose files

Besides the docker-compose files used in the tests, there are other example files in [src/main/resources](https://github.com/xenit-eu/docker-solr/src/master/src/main/resources/).

## Support & Collaboration

These images are updated via pull requests to the [xenit-eu/docker-solr/](https://github.com/xenit-eu/docker-solr/) Github-repository.

**Maintained by:**

Roxana Angheluta <roxana.angheluta@xenit.eu>, Lars Vierbergen <lars.vierbergen@xenit.eu>

## Monitoring

Solr exposes a number of beans which can be used for monitoring via Jmx. Additionally, there are some system beans in java.lang which can be used to monitor memory, garbage collector, Java threads.

For Solr1 and Solr4, tomcat has also specific beans for the thread pool per connector and for session attributes for a specific web application.

For Solr6, Jetty does not expose thread pool + webapp information out-of-the-box.

There are multiple variants for exposing/shipping these metrics.

### [Jmxtrans-agent](https://github.com/jmxtrans/jmxtrans-agent/)

Can be used by including the following sections in the docker-compose-solr file (example below is for solr6):

```
   volumes:
    - ./jmxtrans-agent:/jmxtrans
    ....
   environment:
    - JAVA_OPTS_jmxtrans=-javaagent:/jmxtrans/jmxtrans-agent-1.2.6.jar=/jmxtrans/jmxtrans-agent-solr6.xml
```

Example configuration files are in directory [jmxtrans-agent](src/integrationTest/resources/jmxtrans-agent/).
Update to the latest jar file for jmxtrans-agent.

### [Jmx exporter](https://github.com/prometheus/jmx_exporter)

Currently there are no example configuration files for jmx exporter in this project.

### How to build

Release builds for community images are produced by [Travis](https://travis-ci.org/xenit-eu/) driving Gradle from a `.travis.yml` file.

To build a local version of the _solr_ image:

```
./gradlew buildDockerImage
```

To run the integration tests:
```
./gradlew integrationTests
```

To see all available tasks:
```
./gradlew tasks
```

If you have access to [Alfresco private repository](https://artifacts.alfresco.com/nexus/content/groups/private/) add the repository to build.gradle and add -Penterprise to your build command.

## Solr backup

In the case of a non-sharded setup, solr index is backed-up via a scheduled job in Alfresco. 
Parameters for the backup (location, maximum number of backups to keep) are set on Alfresco's side and passed to solr via the scheduled job, which calls the replication handler from solr.
By default they are /opt/alfresco/alf_data/solrBackup for solr1, /opt/alfresco/alf_data/solr4Backup for solr4 and /opt/alfresco-search-services/data/solr6Backup for solr6.

In the case of a sharded setup, backup needs to be done manually.

## FAQ

### How do I access the Tomcat debugport?

Set the environment variable DEBUG=true. The debug port is 8000.

### How do I enable JMX?

Set the environment variable JMX_ENABLED=true. Jmx port is 5000.
