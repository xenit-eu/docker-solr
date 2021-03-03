#!/bin/bash

echo "Solr init healthcheck start"    

SOLR_DIR_ROOT="${SOLR_INSTALL_HOME}/solrhome"
ALFRESCO_SSL=${ALFRESCO_SSL:-'https'}
SSL_KEY_STORE=${SSL_KEY_STORE:-'ssl.repo.client.keystore'}
SSL_KEY_STORE_PASSWORD=${SSL_KEY_STORE_PASSWORD:-'kT9X6oe68t'}
SSL_KEY_STORE_ALIAS=${SSL_KEY_STORE_ALIAS:-'ssl.repo'}

CORES_ALFRESCO=${CORES_ALFRESCO:-"alfresco"}
IFS=';' read -r -a DEFAULT_CORES_ALFRESCO <<< "$CORES_ALFRESCO"

JETTY_PORT=${JETTY_PORT:-'8080'}
JETTY_PORT_SSL=${JETTY_PORT_SSL:-'8443'}
if [ $ALFRESCO_SSL != none ]
then
    PORT=$JETTY_PORT_SSL
else
    PORT=$JETTY_PORT
fi
export PORT

echo "#!/bin/bash" >${SOLR_INSTALL_HOME}/healthcheck.sh
if [ $ALFRESCO_SSL != none ]
then
    # for custom certificates, replace browser.pem with certificates able to talk to solr
    # this only works because images use the same keystore for alfresco and solr
    if [ ! -f "${SOLR_DIR_ROOT}/keystore/browser.pem" ]
    then
	    keytool -importkeystore -srckeystore "${SOLR_DIR_ROOT}/keystore/${SSL_KEY_STORE}" -srcstorepass ${SSL_KEY_STORE_PASSWORD} -srcstoretype JCEKS -srcalias ${SSL_KEY_STORE_ALIAS} -destkeystore  "${SOLR_DIR_ROOT}/keystore/browser.p12" -deststoretype pkcs12 -destalias ssl.repo -deststorepass alfresco -destkeypass alfresco
	    openssl pkcs12 -in "${SOLR_DIR_ROOT}/keystore/browser.p12" -out "${SOLR_DIR_ROOT}/keystore/browser.pem" -nodes -passin pass:alfresco
    fi
    echo "status=\$(curl -f -k -L -w %{http_code} -s -E ${SOLR_DIR_ROOT}/keystore/browser.pem -o /dev/null https://localhost:${PORT}/solr/${DEFAULT_CORES_ALFRESCO[0]}/admin/ping)" >>${SOLR_INSTALL_HOME}/healthcheck.sh
else
    echo "status=\$(curl -f -L -w %{http_code} -s -o /dev/null http://localhost:${PORT}/solr/${DEFAULT_CORES_ALFRESCO[0]}/admin/ping)" >>${SOLR_INSTALL_HOME}/healthcheck.sh 
fi
echo "if [[ \"\$status\" -ne 200 ]] ; then exit 1 ; else exit 0 ; fi" >>${SOLR_INSTALL_HOME}/healthcheck.sh

echo "Solr init healthcheck end"        

    

