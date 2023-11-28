#!/bin/bash

function startRestore {
  if [ -z "${RESTORE_BACKUP_NAME}" ]; then
    restorename=""
  else
    restorename="&name=${RESTORE_BACKUP_NAME}"
  fi

  echo "*************** Starting solr without tracking **************************"
  setOption enable.alfresco.tracking false "${SOLR_DIR_ROOT}/alfresco/conf/solrcore.properties"

  gosu "${user}" "${SOLR_INSTALL_HOME}/solr/bin/solr" start -m "${JAVA_XMX}" -p "${PORT}" -h "${SOLR_HOST}" -s "${SOLR_DIR_ROOT}" -a "${JAVA_OPTS}"

  if [ "$ALFRESCO_SSL" != "none" ] && [ "$ALFRESCO_SSL" != "secret" ]; then
    echo "*************** Waiting for solr to return 200 for /solr/alfresco/admin/ping **************************"
    STATUS=0
    while [ "$STATUS" -ne "200" ]; do
      if [ "$STATUS" -ne "0" ]; then
        sleep 5
      fi
      STATUS=$(curl -s -k -E "${SOLR_DIR_ROOT}/keystore/browser.pem" -o /dev/null -I -w '%{http_code}' https://localhost:${PORT}/solr/alfresco/admin/ping)
      echo "STATUS=$STATUS"
    done

    echo "*************** Solr without tracking started **************************"

    echo "************** Calling restore command curl -s -k -E ${SOLR_DIR_ROOT}/keystore/browser.pem https://localhost:${PORT}/solr/alfresco/replication?command=restore&repository=s3&location=s3:///${restorename}"
    curl -s -k -E "${SOLR_DIR_ROOT}/keystore/browser.pem" "https://localhost:${PORT}/solr/alfresco/replication?command=restore&repository=s3&location=s3:///${restorename}"

    restorestatus=$(curl -s -k -E "${SOLR_DIR_ROOT}/keystore/browser.pem" "https://localhost:${PORT}/solr/alfresco/replication?command=restorestatus&wt=json" | jq .restorestatus.status)

    # wait until restore is complete
    while [ "\"In Progress\"" = ${restorestatus} ]; do
      sleep 5
      echo "restorestatus=$restorestatus"
      restorestatus=$(curl -s -k -E "${SOLR_DIR_ROOT}/keystore/browser.pem" "https://localhost:${PORT}/solr/alfresco/replication?command=restorestatus&wt=json" | jq .restorestatus.status)
    done
    if [ "\"success\"" = ${restorestatus} ]; then
      echo "Restore successful"
    else
      echo "Restore was not successful"
    fi
    echo "*************** Restore finished **************************"

  else

    echo "*************** Waiting for solr to return 200 for /solr/alfresco/admin/ping **************************"
    STATUS=0
    while [ "$STATUS" -ne "200" ]; do
      if [ "$STATUS" -ne "0" ]; then
        sleep 5
      fi
      STATUS=$(curl -s -o /dev/null -I -w '%{http_code}' http://localhost:${PORT}/solr/alfresco/admin/ping)
      echo "STATUS=$STATUS"
    done

    echo "*************** Solr without tracking started **************************"

    echo "**************** Calling restore command curl -s http://localhost:${PORT}/solr/alfresco/replication?command=restore&repository=s3&location=s3:///${restorename}"
    curl -s "http://localhost:${PORT}/solr/alfresco/replication?command=restore&repository=s3&location=s3:///${restorename}"
    restorestatus=$(curl -s "http://localhost:${PORT}/solr/alfresco/replication?command=restorestatus&wt=json" | jq .restorestatus.status)
    # wait until restore is complete
    while [ "\"In Progress\"" = ${restorestatus} ]; do
      sleep 5
      echo "restorestatus=$restorestatus"
      restorestatus=$(curl -s "http://localhost:${PORT}/solr/alfresco/replication?command=restorestatus&wt=json" | jq .restorestatus.status)
    done
    if [ "\"success\"" = ${restorestatus} ]; then
      echo "Restore successful"
    else
      echo "Restore was not successful"
    fi
    echo "*************** Restore finished **************************"
  fi

  echo "*************** Stopping solr without tracking **************************"
  gosu ${user} ${SOLR_INSTALL_HOME}/solr/bin/solr stop
  sleep 30
  setOption enable.alfresco.tracking true "${SOLR_DIR_ROOT}/alfresco/conf/solrcore.properties"
  echo "*************** Solr without tracking stopped **************************"
}

set -e

echo "Solr restore from backup start"

if [ -z "${RESTORE_FROM_BACKUP}" ]; then
  echo "No index backup restore requested, exiting"
else
  # Check if the index properties file exists , it means previous restore already happened
  if [ ! -e "${SOLR_DATA_ROOT}/index/alfresco/index.properties" ]; then
    echo "index.properties file doesn't exists proceeding with further verification"
    # Check if the directory exists
    if [ -d "${SOLR_DATA_ROOT}/index/alfresco/index" ]; then
      # Check if the directory size is greater than 100 kilobytes
      if [ "$(du -s "${SOLR_DATA_ROOT}/index/alfresco/index" | cut -f 1)" -gt 100 ]; then
        echo "Index folder exists and is sufficiently large, skipping backup restore"
      else
        startRestore
      fi
    else
      # Directory does not exist
      echo "Index folder does not exist, proceeding with backup restore"
      startRestore
    fi
  fi
fi

echo "Solr restore from backup end"
