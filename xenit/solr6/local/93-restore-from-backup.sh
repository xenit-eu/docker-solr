#!/bin/bash

set -e

echo "Solr restore from backup start"

if [ -z ${RESTORE_FROM_BACKUP} ]
then
    echo "No index backup restore requested, exiting"
else
    # if data folder is empty restore from backup
    if [ -d "${SOLR_DATA_ROOT}/index/alfresco/index" -a `du -s "${SOLR_DATA_ROOT}/index/alfresco/index" | cut -f 1` -gt 100 ]
    then
        echo "Index folder existing, skipping backup restore"
    else
        setOption enable.alfresco.tracking false "${SOLR_DIR_ROOT}/alfresco/conf/solrcore.properties"
        echo "*************** starting solr without tracking **************************"
        gosu "${user}" "${SOLR_INSTALL_HOME}/solr/bin/solr" start -m "${JAVA_XMX}" -p "${PORT}" -h "${SOLR_HOST}" -s "${SOLR_DIR_ROOT}" -a "${JAVA_OPTS}"
        sleep 30
        echo "*************** solr without tracking started **************************"
        # get the name of latest snapshot to be restored from the backup
        if [ -z ${RESTORE_BACKUP_NAME} ]
        then
            RESTORE_BACKUP_NAME=`curl -s -L -XGET -u ${BACKUP_USERNAME}:${BACKUP_PASSWORD} "http://${BACKUP_ENDPOINT}/${BACKUP_BUCKET}/success?domain=${BACKUP_DOMAIN}" | tail -1 | cut -d '.' -f 2`
        fi
        echo "RESTORE_BACKUP_NAME=${RESTORE_BACKUP_NAME}"
        if [[ ! ${RESTORE_BACKUP_NAME} == "20"* ]]
        then
           echo "Could not find a valid snapshot to restore from, exiting"
        else
            if [ $ALFRESCO_SSL != none ]
            then
	            echo "Calling restore command for ${RESTORE_BACKUP_NAME}"
	            curl -s -k -E "${SOLR_DIR_ROOT}/keystore/browser.pem" "https://localhost:${PORT}/solr/alfresco/replication?command=restore&repository=swarm&location=swarm:///&name=${RESTORE_BACKUP_NAME}"

	            restorestatus=$(curl -s -k -E "${SOLR_DIR_ROOT}/keystore/browser.pem" "https://localhost:${PORT}/solr/alfresco/replication?command=restorestatus&wt=json" | jq .restorestatus.status)

	            # wait until restore is complete
	            while [ "\"In Progress\"" = ${restorestatus} ]
	            do
	                echo "restorestatus=$restorestatus"
	                restorestatus=$(curl -s -k -E "${SOLR_DIR_ROOT}/keystore/browser.pem" "https://localhost:${PORT}/solr/alfresco/replication?command=restorestatus&wt=json" | jq .restorestatus.status)
	                sleep 5
	            done
	            if [  "\"success\"" = ${restorestatus} ]
	            then
                    echo "Restore successful"
                else
                    echo "Restore was not successful"
	            fi
            else
                echo "Calling restore command for ${RESTORE_BACKUP_NAME}"
                curl -s "http://localhost:${PORT}/solr/alfresco/replication?command=restore&repository=swarm&location=swarm:///&name=${RESTORE_BACKUP_NAME}"
                restorestatus=$(curl -s "http://localhost:${PORT}/solr/alfresco/replication?command=restorestatus&wt=json" | jq .restorestatus.status)
                # wait until restore is complete
                while [ "\"In Progress\"" = ${restorestatus} ]
                do
                    echo "restorestatus=$restorestatus"
                    restorestatus=$(curl -s "http://localhost:${PORT}/solr/alfresco/replication?command=restorestatus&wt=json" | jq .restorestatus.status)
                    sleep 5
                done
        	    if [  "\"success\"" = ${restorestatus} ]
                then
                       echo "Restore successful"
                else
                       echo "Restore was not successful"
                fi
            fi
        fi
        
        # stop solr
        gosu ${user} ${SOLR_INSTALL_HOME}/solr/bin/solr stop
        sleep 30

        setOption enable.alfresco.tracking true "${SOLR_DIR_ROOT}/alfresco/conf/solrcore.properties"
    fi
 fi

echo "Solr restore from backup done"
