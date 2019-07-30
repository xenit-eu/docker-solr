# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [v1.0.0] - 2019-07-15 Move to github

### Removed

* [DOCKER-228] Remove license files from the repo

### Added

* [DOCKER-220] Support custom SSL keystore and truststore
* [DOCKER-226] Use REST API for search for solr6

### Fixed

* [DOCKER-231][DOCKER-233] Fix permissions in case of mounts
* [DOCKER-223] Fixed JVM argument for keystore type

## [v0.0.9] - 2019-05-10

### Fixed

* [DOCKER-188] If data folder is a mount or a volume, there are permission errors. Make sure the init script changes permissions on this folder.

## [v0.0.8] - 2019-04-30

### Fixed

* [DOCKER-153] Remove gpg verification
* [DOCKER-176] Create backup folders for solr6

## [v0.0.7] - 2019-03-12

### Removed

* [DOCKER-159] Remove dependency on artifactory.xenit.eu: dependencies are downloaded via gradle

### Added

* [DOCKER-158] Alfresco search services 1.3.0.1. In order to reduce build time for the project, only last version is built per solr flavor.
* [DOCKER-155] Possibility to mount a custom schema and to add custom resources to a core

### Changed

* [DOCKER-161] Separate stages in Jenkinsfile, with composeDown if tests fail or are aborted
* [DOCKER-130] Standardize init script by transforming it into a docker-entrypoint.d script, as ran by java image's ENTRYPOINT
* [DOCKER-184] Refactor docker-solr to use nested configurations and overlayed docker-compose files

## [v0.0.6] - 2019-02-26

### Fixed

* [DOCKER-151] Suggester not working for solr6
* [DOCKER-152] Wrong check when copying the template folder for solr6

## [v0.0.5] - 2018-10-26

### Added

* [DOCKER-112] Integration with vault

### Fixed

* [DOCKER-135] Remove file appender, the only logs are on stdout and stderr which can be externalized

## [v0.0.4] - 2018-09-25

### Added

* [DOCKER-115] Move healthchecks to Dockerfiles
* [DOCKER-119] Generic mechanism to set variables via JAVA_OPTS_\<variable\>
* [DOCKER-121] Options for suggester and facetable categories for solr6
* [DOCKER-118] Generic mechanism to set variables via GLOBAL_WORKSPACE_, GLOBAL_ARCHIVE_, GLOBAL_ environment variables

### Fixed

* [DOCKER-91] Redirect port was not parametrized in server.xml, therefore it was not possible to change it
* [DOCKER-116] Change ports via variables JETTY_PORT and JETTY_PORT_SSL
* [DOCKER-122] Solr1, solr4 and solr6 run with the same uid+gid

### Changed

* [DOCKER-109] Adapt all solr images to start from Xenit base images

### Removed

* [DOCKER-120] Removed variables SOLR_PORT, SOLR_PORT_SSL = they are set with TOMCAT_PORT, TOMCAT_PORT_SSL and JETTY_PORT, JETTY_PORT_SSL
* [DOCKER-117] Removed custom variables for caches. They can be set via GLOBAL_WORKSPACE_, GLOBAL_ARCHIVE_, GLOBAL_ options

## [v0.0.3] - 2018-09-10

### Added

* [DOCKER-77] Smoke tests: search + status for shards (if testsSharded = true)
* [DOCKER-104] Alfresco search services 1.2.0

### Changed

* [DOCKER-90] Restructuring: global + local resources, single build

## [v0.0.2] - 2018-09-04

### Added

* [DOCKER-106] Parameter CORES_TO_TRACK as a ; separated list: e.g. CORES_TO_TRACK=alfresco;archive;version
* [DOCKER-103] Parameters SOLR_DATA_DIR, SOLR_MODEL_DIR, SOLR_CONTENT_DIR to changed default locations
* [DOCKER-88] Solr1
* [DOCKER-56] Alfresco search services 1.1.1

### Changed

* [DOCKER-105] Refactored core creation: use static creation for default cores, same mechanism as for shards
* [DOCKER-66] Naming image

## [v0.0.1] - 2018-05-23

### Added

* [DOCKER-39] Support for JAVA_OPTS_\<variable\> variables, allowing for overrides in different docker-compose files.
* [DOCKER-41] Support for SSL in Alfresco search services 1.0.0 (solr6)