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
        if [ -z ${RESTORE_BACKUP_NAME} ]
        then
            restorename=""
        else
            restorename="&name=${RESTORE_BACKUP_NAME}"
        fi
	
        if [ $ALFRESCO_SSL != none ]
        then
            echo "*************** Starting solr without tracking **************************"
            setOption enable.alfresco.tracking false "${SOLR_DIR_ROOT}/alfresco/conf/solrcore.properties"

            gosu "${user}" "${SOLR_INSTALL_HOME}/solr/bin/solr" start -m "${JAVA_XMX}" -p "${PORT}" -h "${SOLR_HOST}" -s "${SOLR_DIR_ROOT}" -a "${JAVA_OPTS}"
	    STATUS=$(curl -s -k -E "${SOLR_DIR_ROOT}/keystore/browser.pem" -o /dev/null -I -w '%{http_code}' https://localhost:${PORT}/solr/alfresco/admin/ping)
	    echo "STATUS=$STATUS"
	    while [ "$STATUS" -ne '200' ]
	    do
		sleep 5
		STATUS=$(curl -s -k -E "${SOLR_DIR_ROOT}/keystore/browser.pem" -o /dev/null -I -w '%{http_code}' https://localhost:${PORT}/solr/alfresco/admin/ping)
		echo "STATUS=$STATUS"		
	    done
            echo "*************** Solr without tracking started **************************"

	    
	    echo "************** Calling restore command curl -s -k -E ${SOLR_DIR_ROOT}/keystore/browser.pem https://localhost:${PORT}/solr/alfresco/replication?command=restore&repository=swarm&location=s3:///${restorename}"
	    curl -s -k -E "${SOLR_DIR_ROOT}/keystore/browser.pem" "https://localhost:${PORT}/solr/alfresco/replication?command=restore&repository=swarm&location=s3:///${restorename}"
	    
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
	    echo "*************** Restore finished **************************"	    
        else
            echo "*************** Starting solr without tracking **************************"
            setOption enable.alfresco.tracking false "${SOLR_DIR_ROOT}/alfresco/conf/solrcore.properties"
	    
            gosu "${user}" "${SOLR_INSTALL_HOME}/solr/bin/solr" start -m "${JAVA_XMX}" -p "${PORT}" -h "${SOLR_HOST}" -s "${SOLR_DIR_ROOT}" -a "${JAVA_OPTS}"
	    STATUS=$(curl -s -o /dev/null -I -w '%{http_code}' http://localhost:${PORT}/solr/alfresco/admin/ping)
	    echo "STATUS=$STATUS"
	    while [ "$STATUS" -ne '200' ]
	    do
		sleep 5
		STATUS=$(curl -s -o /dev/null -I -w '%{http_code}' http://localhost:${PORT}/solr/alfresco/admin/ping)
		echo "STATUS=$STATUS"
	    done
            echo "*************** Solr without tracking started **************************"

	    
            echo "**************** Calling restore command curl -s http://localhost:${PORT}/solr/alfresco/replication?command=restore&repository=swarm&location=s3:///${restorename}"
            curl -s "http://localhost:${PORT}/solr/alfresco/replication?command=restore&repository=swarm&location=s3:///${restorename}"
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
	    echo "*************** Restore finished **************************"
        fi
	
        echo "*************** Stopping solr without tracking **************************"
        gosu ${user} ${SOLR_INSTALL_HOME}/solr/bin/solr stop
        sleep 30
	setOption enable.alfresco.tracking true "${SOLR_DIR_ROOT}/alfresco/conf/solrcore.properties"
	echo "*************** Solr without tracking stopped **************************"	    
    fi
 fi

echo "Solr restore from backup end"
