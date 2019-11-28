#!/bin/bash

echo "Solr init healthcheck start"    

SOLR_DIR_ROOT="${SOLR_INSTALL_HOME}/solrhome"
ALFRESCO_SSL=${ALFRESCO_SSL:-'https'}
SSL_KEY_STORE=${SSL_KEY_STORE:-'ssl.repo.client.keystore'}
SSL_KEY_STORE_PASSWORD=${SSL_KEY_STORE_PASSWORD:-'kT9X6oe68t'}

JETTY_PORT=${JETTY_PORT:-'8080'}
JETTY_PORT_SSL=${JETTY_PORT_SSL:-'8443'}
if [ $ALFRESCO_SSL != none ]
then
    PORT=$JETTY_PORT_SSL
else
    PORT=$JETTY_PORT
fi
export PORT

if [ $ALFRESCO_SSL != none ]
then
    if [ ! -f "${SOLR_DIR_ROOT}/keystore/browser.p12" ]
    then
	keytool -importkeystore -srckeystore "${SOLR_DIR_ROOT}/keystore/${SSL_KEY_STORE}" -srcstorepass ${SSL_KEY_STORE_PASSWORD} -srcstoretype JCEKS -srcalias ssl.repo -destkeystore  "${SOLR_DIR_ROOT}/keystore/browser.p12" -deststoretype pkcs12 -destalias ssl.repo -deststorepass alfresco
	openssl pkcs12 -in "${SOLR_DIR_ROOT}/keystore/browser.p12" -out "${SOLR_DIR_ROOT}/keystore/browser.pem" -nodes -passin pass:alfresco
    fi
    echo "curl -f -k -L -E ${SOLR_DIR_ROOT}/keystore/browser.pem https://localhost:${PORT}/solr >/dev/null" >${SOLR_INSTALL_HOME}/healthcheck.sh
else
    echo "curl -f -L  http://localhost:${PORT}/solr >/dev/null" >${SOLR_INSTALL_HOME}/healthcheck.sh    
fi

echo "Solr init healthcheck end"        

    

