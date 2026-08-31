#!/bin/bash

# Initialize environment for SOLR. JAVA_OPTS is passed by caller.
. "${SOLR_INSTALL_HOME:-/opt/alfresco-search-services}/solr-env.sh"

exec gosu "$SOLR_USER" "${SOLR_INSTALL_HOME}/solr/bin/solr" start -f \
  -m "$JAVA_XMX" \
  -p "$PORT" \
  -h "$SOLR_HOST" \
  -s "$SOLR_DIR_ROOT" \
  -a "$JAVA_OPTS"
