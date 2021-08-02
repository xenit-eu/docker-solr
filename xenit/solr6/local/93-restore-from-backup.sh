#!/bin/bash

set -e

BACKUP_NAME=${BACKUP_NAME:-`date '+%Y-%m-%d'`}

echo "Solr restore from backup start"

if [ -z $RESTORE_FROM_BACKUP ]
then
    echo "The index should not be restored from backup, exiting"
else
    # if data folder is empty restore from backup
    # backup name mandatory
    if [ -d "${SOLR_DATA_ROOT}/index/alfresco/index" ]
    then
        echo "Index folder existing, skipping backup restore"
        ls -ltr "${SOLR_DATA_ROOT}/index/alfresco/index"
    else
        setOption enable.alfresco.tracking false "${SOLR_DIR_ROOT}/alfresco/conf/solrcore.properties"
        echo "*************** starting solr without tracking **************************"
        gosu "${user}" "${SOLR_INSTALL_HOME}/solr/bin/solr" start -m "${JAVA_XMX}" -p "${PORT}" -h "${SOLR_HOST}" -s "${SOLR_DIR_ROOT}" -a "${JAVA_OPTS}"
        sleep 30
        echo "*************** solr without tracking started **************************"
        # restore from backup
        if [ $ALFRESCO_SSL != none ]
        then
            # try to restore from backups from last 3 days
            for i in 1 2 3
            do
	            echo "Calling restore command for ${BACKUP_NAME}"
	            curl -s -k -E "${SOLR_DIR_ROOT}/keystore/browser.pem" "https://localhost:${PORT}/solr/alfresco/replication?command=restore&repository=s3&location=s3:///&name=${BACKUP_NAME}"

	            restorestatus=$(curl -s -k -E "${SOLR_DIR_ROOT}/keystore/browser.pem" "https://localhost:${PORT}/solr/alfresco/replication?command=restorestatus&wt=json" | jq .restorestatus.status)

	            if [ ! "\"In Progress\"" = ${restorestatus} ]
	            then
                    BACKUP_NAME=`date -d "$BACKUP_NAME - 1 day" '+%Y-%m-%d'`
	                continue
	            fi
	            # wait until restore is complete
	            while [ "\"In Progress\"" = ${restorestatus} ]
	            do
	                echo "restorestatus=$restorestatus"
	                restorestatus=$(curl -s -k -E "${SOLR_DIR_ROOT}/keystore/browser.pem" "https://localhost:${PORT}/solr/alfresco/replication?command=restorestatus&wt=json" | jq .restorestatus.status)
	                sleep 5
	                done
	            if [ ! "\"success\"" = ${restorestatus} ]
	            then
                    echo "Restore successful"
                    break
	            fi
	            BACKUP_NAME=`date -d "$BACKUP_NAME - 1 day" '+%Y-%m-%d'`
            done
        else
            # try to restore from backups from last 3 days
            for i in 1 2 3
                do
	            echo "Calling restore command for ${BACKUP_NAME}"
	            curl -s "http://localhost:${PORT}/solr/alfresco/replication?command=restore&repository=s3&location=s3:///&name=${BACKUP_NAME}"
	            restorestatus=$(curl -s "http://localhost:${PORT}/solr/alfresco/replication?command=restorestatus&wt=json" | jq .restorestatus.status)
	            if [ ! "\"In Progress\"" = ${restorestatus} ]
	            then
	                BACKUP_NAME=`date -d "$BACKUP_NAME - 1 day" '+%Y-%m-%d'`
	                continue
	            fi
	            # wait until restore is complete
	            while [ "\"In Progress\"" = ${restorestatus} ]
	            do
	                echo "restorestatus=$restorestatus"
	                restorestatus=$(curl -s "http://localhost:${PORT}/solr/alfresco/replication?command=restorestatus&wt=json" | jq .restorestatus.status)
	                sleep 5
	            done
	        	if [ ! "\"success\"" = ${restorestatus} ]
	            then
                    echo "Restore successful"
                    break
	            fi
	            BACKUP_NAME=`date -d "$BACKUP_NAME - 1 day" '+%Y-%m-%d'`
            done
        fi

        # stop solr
        gosu ${user} ${SOLR_INSTALL_HOME}/solr/bin/solr stop
        sleep 30

        setOption enable.alfresco.tracking true "${SOLR_DIR_ROOT}/alfresco/conf/solrcore.properties"
    fi
 fi

echo "Solr restore from backup done"
