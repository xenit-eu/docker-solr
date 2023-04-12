#!/bin/bash

# should get environment var from docker image / container:
# ${SOLR_INSTALL_HOME} = /opt/alfresco-search-services
# ${JSON_LOGGING} = true
# ${ACCESS_LOGGING} = true

set -e

JSON_LOGGING=${JSON_LOGGING:-false}
ACCESS_LOGGING=${ACCESS_LOGGING:-false}

echo "Solr init logging start - JSON_LOGGING=${JSON_LOGGING}; ACCESS_LOGGING=${ACCESS_LOGGING}"
echo "Working directory is..."
pwd

# if JSON_LOGGING is true, we manipulate the layout of the logging
if [ $JSON_LOGGING = true ]; then
  sed -i "s/log4j.appender.CONSOLE.layout.ConversionPattern=.*//g" ${SOLR_INSTALL_HOME}/logs/log4j.properties
  sed -i "s/log4j.appender.CONSOLE.layout=org.apache.log4j.EnhancedPatternLayout/log4j.appender.CONSOLE.layout=eu.xenit.logging.json.log4j.JsonLayout\nlog4j.appender.CONSOLE.layout.Type=application\nlog4j.appender.CONSOLE.layout.Component=solr/g" ${SOLR_INSTALL_HOME}/logs/log4j.properties
fi

if [ $ACCESS_LOGGING = true ]; then
  echo "ACCESS_LOGGING is true"
else
  echo "ACCESS_LOGGING is false"
fi

echo "Solr init logging end"
