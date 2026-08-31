#!/bin/bash

echo "Solr init env start"

# All the init scripts run in the same environment, so as a first step
# initialize the environment with derived values.
. "${SOLR_INSTALL_HOME}/solr-env.sh"

if [ "$SOLR_SSL_ENABLED" = true ]; then
  # for custom certificates, replace browser.pem with certificates able to talk to solr
  # this only works because images use the same keystore for alfresco and solr
  if [ ! -f "$SOLR_BROWSER_PEM" ]; then
    keytool -importkeystore -srckeystore "${SOLR_DIR_ROOT}/keystore/${SSL_KEY_STORE}" -srcstorepass ${SSL_KEY_STORE_PASSWORD} -srcstoretype JCEKS -srcalias ${SSL_KEY_STORE_ALIAS} -destkeystore "${SOLR_DIR_ROOT}/keystore/browser.p12" -deststoretype pkcs12 -destalias ssl.repo -deststorepass alfresco -destkeypass alfresco
    openssl pkcs12 -in "${SOLR_DIR_ROOT}/keystore/browser.p12" -out "$SOLR_BROWSER_PEM" -nodes -passin pass:alfresco
  fi
fi

echo "Solr init env end"
