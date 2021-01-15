# Solr in Docker
Alfresco-specific solr docker images, compatible with Alfresco versions higher than 4.2.

## Images created

* [`alfresco-solr1`] = solr1 images, using tomcat
* [`alfresco-solr4`] = solr4 images, using tomcat
* [`alfresco-solr6`] = solr6 images (alfresco search services), using jetty

* [`alfresco-solr4-xenit`] = solr4 images with [alfred-telemetry-solr](https://github.com/xenit-eu/alfred-telemetry) installed
* [`alfresco-solr6-xenit`] = solr6 images (alfresco search services) with [alfred-telemetry-solr](https://github.com/xenit-eu/alfred-telemetry) installed

## Supported Tags

* [`:5.1,5`, `:5.2.5`] = minor, major, revision for solr1 and solr4
* [`:1.3.1`, `:1.4.0`] = version of the alfresco search services used for solr6

## Overview

This is the repository building Solr Docker images.

All images are automatically built by [jenkins-2](https://jenkins-2.xenit.eu) and published to [hub.xenit.eu](https://hub.xenit.eu).

Community images are built by a [github workflow](https://github.com/xenit-eu/docker-solr/actions) and published to [docker hub](https://hub.docker.com/u/xenit).

## Example docker-compose files

Each time images are built, tests are automatically ran on containers started via docker-compose files.

If sharding is involved, then a valid license file which allows clustering is needed (\*)

(\*) this is conform alfresco documentation, although in practice I could run a sharded setup also without a clustering license. The admin console does not have the Sharding screen, but indexing and search actually works.

## Environment variables

There are several environment variables available to tweak the behaviour. The variables are read by an init script which further replaces them in the relevant files. Such relevant files include:

* solrcore.properties
* schema.xml
* server.xml (ports, ssl-related properties for tomcat-based images)
* solr.in.sh (ports, ssl-related properties, paths for jetty-based images)

solrcore.properties can be set via a generic mechanism by setting environment variables of the form
GLOBAL_WORKSPACE\_\<parameter\> for workspace store,
GLOBAL_ARCHIVE\_<\parameter\> for archive store,
GLOBAL\_\<parameter\> for all cores.

A subset of the properties have also dedicated environment variables e.g. ALFRESCO_ENABLE_TRACKING. Generic variables take precedence.

See also environment variables from lower layers: [`docker-openjdk`](https://github.com/xenit-eu/docker-openjdk) and [`docker-tomcat`](https://github.com/xenit-eu/docker-tomcat).

| Variable                    | solrcore.property variable | java variable                                                | Default                                                      | Comments |
| --------------------------- | --------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ | --------------------------- |
| TEMPLATE                  | alfresco.template |                                                              | rerank                                                   |  |
| CORES_TO_TRACK | | | alfresco;archive | loop over values to create config folders <br> solr6 only |
| CORES_ALFRESCO | | | alfresco | in case of sharded setups, cores to be created on the current host, separated by ";" <br> Example: alfresco-01;alfresco-02 <br> Leave default for non-sharded setup <br> solr6 only |
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
| JETTY_PORT | |  | 8080 | solr6 only |
| JETTY_PORT_SSL | |  | 8443 | solr6 only |
| GLOBAL_WORKSPACE_\<variable\> | \<variable\> | | | for workspace core or shards |
| GLOBAL_ARCHIVE_\<variable\> | \<variable\> | | | for archive core |
| GLOBAL_ALL_\<variable\> | \<variable> | | | for all cores |
| GLOBAL_<core>_\<variable\> | \<variable> | | | for specific core |
| \* SSL_KEY_STORE | | | ssl.repo.client.keystore for solr6, ssl.keystore for solr4|  |
| \* SSL_KEY_STORE_PASSWORD' | | | kT9X6oe68t | |
| \* SSL_TRUST_STORE | | | ssl.repo.client.truststore for solr6, ssl.truststore for solr4 | |
| \* SSL_TRUST_STORE_PASSWORD | | | kT9X6oe68t | |

\* = tested for solr6

## Docker-compose files

Besides the docker-compose files used in the tests, there are other example files in [src/main/resources](https://github.com/xenit-eu/docker-solr/src/master/src/main/resources/).

## Support & Collaboration

These images are updated via pull requests to the [xenit-eu/docker-solr/](https://github.com/xenit-eu/docker-solr/) Github-repository.

**Maintained by:**

Roxana Angheluta <roxana.angheluta@xenit.eu>

## Monitoring

Xenit-specific variants of the images contain [alfred-telemetry-solr](https://github.com/xenit-eu/alfred-telemetry) resources necessary for monitoring. See [alfred-telemetry-solr](https://github.com/xenit-eu/alfred-telemetry) for more details.

### [Jmxtrans-agent](https://github.com/jmxtrans/jmxtrans-agent/)

Can be used by including the following sections in the docker-compose-solr file (example below is for solr6):

```yaml
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

To build a local version of the _solr_ image:

```bash
./gradlew buildDockerImage
```

To run the integration tests:

```bash
./gradlew integrationTests
```

To see all available tasks:

```bash
./gradlew tasks
```

If you have access to [Alfresco private repository](https://artifacts.alfresco.com/nexus/content/groups/private/) add the repository to build.gradle and add

```bash
-Penterprise
```

to your build command.

## Solr backup

In the case of a non-sharded setup, solr index is backed-up via a scheduled job in Alfresco.
Parameters for the backup (location, maximum number of backups to keep) are set on Alfresco's side and passed to solr via the scheduled job, which calls the replication handler from solr.
By default they are /opt/alfresco/alf_data/solrBackup for solr1, /opt/alfresco/alf_data/solr4Backup for solr4 and /opt/alfresco-search-services/data/solr6Backup for solr6.

In the case of a sharded setup, backup needs to be done manually.

## FAQ

### How do I take a thread dump?

Either use:

* ```kill -3 1``` inside the container and then look at the logs of the container
* ```jstack -l 1``` inside the container. Make sure you are running the command as user 'solr'.
