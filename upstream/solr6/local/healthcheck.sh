#!/bin/bash

. "${SOLR_INSTALL_HOME:-/opt/alfresco-search-services}/solr-env.sh"

# admin/ping is only served by an Alfresco core, so probe the first one on this node.
PING_PATH="solr/${DEFAULT_CORES_ALFRESCO[0]}/admin/ping"

if [ "$SOLR_SSL_ENABLED" = true ]; then
  status=$(curl -f -k -L -w '%{http_code}' -s -E "$SOLR_BROWSER_PEM" -o /dev/null "https://localhost:${PORT}/${PING_PATH}")
else
  status=$(curl -f -L -w '%{http_code}' -s -o /dev/null "http://localhost:${PORT}/${PING_PATH}")
fi

[[ "$status" -eq 200 ]] || exit 1
