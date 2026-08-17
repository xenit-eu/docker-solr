#!/bin/bash

# Shared derivation of the values that the entrypoint scripts, healthcheck.sh and
# startup.sh all need. This file is sourced, never executed: it only sets variables, so
# it is safe to pull in from several places and more than once.

SOLR_INSTALL_HOME=${SOLR_INSTALL_HOME:-'/opt/alfresco-search-services'}
SOLR_DIR_ROOT="${SOLR_INSTALL_HOME}/solrhome"
SOLR_DATA_ROOT="${SOLR_INSTALL_HOME}/data"

SOLR_HOST=${SOLR_HOST:-'solr'}

SOLR_USER=solr

ALFRESCO_SSL=${ALFRESCO_SSL:-'https'}

# 'none' and 'secret' are the two modes that talk plain HTTP to the repository; anything
# else means mutual TLS, which also moves Solr's own connector to the SSL port.
if [ "$ALFRESCO_SSL" != none ] && [ "$ALFRESCO_SSL" != secret ]; then
  SOLR_SSL_ENABLED=true
else
  SOLR_SSL_ENABLED=false
fi

JETTY_PORT=${JETTY_PORT:-'8080'}
JETTY_PORT_SSL=${JETTY_PORT_SSL:-'8443'}
if [ "$SOLR_SSL_ENABLED" = true ]; then
  PORT=$JETTY_PORT_SSL
else
  PORT=$JETTY_PORT
fi
export PORT

JAVA_XMS=${JAVA_XMS:-'512M'}
JAVA_XMX=${JAVA_XMX:-'2048M'}

CORES_ALFRESCO=${CORES_ALFRESCO:-'alfresco'}
IFS=';' read -r -a DEFAULT_CORES_ALFRESCO <<<"$CORES_ALFRESCO"

SSL_KEY_STORE=${SSL_KEY_STORE:-'ssl.repo.client.keystore'}
SSL_KEY_STORE_PASSWORD=${SSL_KEY_STORE_PASSWORD:-'kT9X6oe68t'}
SSL_KEY_STORE_ALIAS=${SSL_KEY_STORE_ALIAS:-'ssl.repo'}
SSL_TRUST_STORE=${SSL_TRUST_STORE:-'ssl.repo.client.truststore'}
SSL_TRUST_STORE_PASSWORD=${SSL_TRUST_STORE_PASSWORD:-'kT9X6oe68t'}

SOLR_BROWSER_PEM="${SOLR_DIR_ROOT}/keystore/browser.pem"
