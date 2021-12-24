#!/bin/bash

# should get environment var from docker image / container:
# ${SOLR_INSTALL_HOME} = /opt/alfresco-search-services

set -e

echo "Solr init start"

SOLR_DATA_ROOT="$SOLR_INSTALL_HOME/data"
DIR_ROOT=${DIR_ROOT:-'/opt/alfresco-search-services/data'}
SOLR_BACKUP_DIR=${SOLR_BACKUP_DIR:-'/opt/alfresco-search-services/data/solr6Backup'}
SOLR_HOST=${SOLR_HOST:-'solr'}

CORES_TO_TRACK=${CORES_TO_TRACK:-"alfresco;archive"}
IFS=';' read -r -a DEFAULT_CORES <<< "$CORES_TO_TRACK"

CORES_ALFRESCO=${CORES_ALFRESCO:-"alfresco"}
IFS=';' read -r -a DEFAULT_CORES_ALFRESCO <<< "$CORES_ALFRESCO"

TEMPLATE=${TEMPLATE:-'rerank'}

ALFRESCO_SOLR_SUGGESTER_ENABLED=${ALFRESCO_SOLR_SUGGESTER_ENABLED:-'true'}
ALFRESCO_SOLR_FACETABLE_CATEGORIES_ENABLED=${ALFRESCO_SOLR_FACETABLE_CATEGORIES_ENABLED:-'false'}

JAVA_XMS=${JAVA_XMS:-'512M'}
JAVA_XMX=${JAVA_XMX:-'2048M'}

CONFIG_FILE_SOLR_START="$SOLR_INSTALL_HOME/solr.in.sh"

CUSTOM_SCHEMA=${CUSTOM_SCHEMA:-'false'}
CUSTOM_RESOURCES=${CUSTOM_RESOURCES:-'false'}

SSL_TRUST_STORE=${SSL_TRUST_STORE:-'ssl.repo.client.truststore'}
SSL_TRUST_STORE_PASSWORD=${SSL_TRUST_STORE_PASSWORD:-'kT9X6oe68t'}

function setJavaOption {
    JAVA_OPTS="$JAVA_OPTS $2"
}

function setOption {
    if grep --quiet -e "$1\s*=" "$3"; then
        # replace option
        sed -i "s#^\s*\($1\s*=\s*\).*\$#\1$2#" $3
	    sed -i "s#^\#\s*\($1\s*=\s*\).*\$#\1$2#" $3
        if (( $? )); then
            echo "setOption failed (replacing option $1=$2 in $3)"
            exit 1
        fi
    else
        # add option if it does not exist
        echo "$1=$2" >> $3
    fi
}

# Options starting with GLOBAL_ALL_xxx are valid for all cores
# Options starting with GLOBAL_<core>_xxx are valid for core=<core>
# Options starting with GLOBAL_WORKSPACE_xxx are valid for any core containing alfresco (from man bash: the string  to  the  right  of  the operator  is considered an extended regular expression and matched accordingly (as in regex(3)))
function setGlobalOptions {
    file=$1
    coreName=$2
    IFS=$'\n'
    for i in `env`
    do
	    envCoreName=`echo $i | cut -d '=' -f 1 | cut -d '_' -f 2`
	    if [[ $envCoreName = $coreName ]] || [[ $envCoreName = "ALL" ]] || [[ $envCoreName = "WORKSPACE" && $coreName =~ alfresco ]]
	    then
            key=`echo $i | cut -d '=' -f 1 | cut -d '_' -f 3-`
            value=`echo $i | cut -d '=' -f 2-`
            setOption $key $value "$file"
	    fi
    done
}

function escapeFile {
    sed -i "s#:#\:#g" $1
}

function createCoreStatically {
    coreName="$1"
    newCore="$2"
    
    echo "Creating Alfresco core=$coreName in $newCore"
    CONFIG_FILE_CORE=$newCore/conf/solrcore.properties
    if [ ! -d  "$newCore" ]
    then
        cp -r ${SOLR_DIR_ROOT}/templates/$TEMPLATE $newCore
        FILE_CORE=$newCore/core.properties
        touch $FILE_CORE
        setOption 'name' "$coreName" "$FILE_CORE"
    fi
    setOption 'data.dir.root' "${SOLR_DATA_DIR:-$SOLR_DATA_ROOT/index}" "$CONFIG_FILE_CORE"
    setOption 'data.dir.store' "$coreName" "$CONFIG_FILE_CORE"
    setOption 'alfresco.template' "${TEMPLATE}" "$CONFIG_FILE_CORE"
    setOption 'alfresco.host' "${ALFRESCO_HOST:-alfresco}" "$CONFIG_FILE_CORE"
    setOption 'alfresco.port' "${ALFRESCO_PORT:-8080}" "$CONFIG_FILE_CORE"
    setOption 'alfresco.port.ssl' "${ALFRESCO_PORT_SSL:-8443}" "$CONFIG_FILE_CORE"
    setOption 'alfresco.secureComms' "$ALFRESCO_SSL" "$CONFIG_FILE_CORE"
}

function makeConfigs {
    SHARED_PROPERTIES=${SOLR_DIR_ROOT}/conf/shared.properties
    setOption 'solr.host' "$SOLR_HOST" "$SHARED_PROPERTIES"
    setOption 'solr.port' "$PORT" "$SHARED_PROPERTIES"
    
    if [ $ALFRESCO_SOLR_SUGGESTER_ENABLED = true ]
    then
        setOption 'alfresco.suggestable.property.0' '{http://www.alfresco.org/model/content/1.0}name' "$SHARED_PROPERTIES"
        setOption 'alfresco.suggestable.property.1' '{http://www.alfresco.org/model/content/1.0}title' "$SHARED_PROPERTIES"
        setOption 'alfresco.suggestable.property.2' '{http://www.alfresco.org/model/content/1.0}description' "$SHARED_PROPERTIES"
        setOption 'alfresco.suggestable.property.3' '{http://www.alfresco.org/model/content/1.0}content' "$SHARED_PROPERTIES"
    fi

    # Load envvars starting with SHARED_ and put them in shared.properties
    for i in $(env)
    do
      if [[ "$i" = SHARED_* ]]
      then
            key="$(echo "$i" | cut -d '=' -f 1 | cut -d '_' -f 2-)"
            value="$(echo "$i" | cut -d '=' -f 2-)"
            setOption "$key" "$value" "$SHARED_PROPERTIES"
      fi
    done
    
    for coreName in "${DEFAULT_CORES[@]}"
    do
	    newCore=${SOLR_DIR_ROOT}/$coreName
	    CONFIG_FILE_CORE=$newCore/conf/solrcore.properties
	
        if [ $coreName = alfresco ]
        then
            for coreAlfrescoName in "${DEFAULT_CORES_ALFRESCO[@]}"
            do
                # only use a collection in the case of a real sharded setup
                if [ $coreAlfrescoName != $coreName ]
                then
                    collectionName=${TEMPLATE}-alfresco
                    mkdir -p ${SOLR_DIR_ROOT}/$collectionName
                    newCore=${SOLR_DIR_ROOT}/$collectionName/$coreAlfrescoName
                fi

                CONFIG_FILE_CORE=$newCore/conf/solrcore.properties

                createCoreStatically "$coreAlfrescoName" "$newCore"

                setOption 'alfresco.stores' "workspace://SpacesStore" "$CONFIG_FILE_CORE"
                setOption 'enable.alfresco.tracking' "${ALFRESCO_ENABLE_TRACKING:-true}" "$CONFIG_FILE_CORE"
                setOption 'alfresco.index.transformContent' "${ALFRESCO_INDEX_CONTENT:-true}" "$CONFIG_FILE_CORE"
                setOption 'alfresco.corePoolSize' "${ALFRESCO_CORE_POOL_SIZE:-8}" "$CONFIG_FILE_CORE"
                setOption 'alfresco.doPermissionChecks' "${ALFRESCO_DO_PERMISSION_CHECKS:-true}" "$CONFIG_FILE_CORE"
                setOption 'solr.suggester.enabled' "$ALFRESCO_SOLR_SUGGESTER_ENABLED" "$CONFIG_FILE_CORE"
                # SOLR_BACKUP_DIR only useful for ASS v2.0.2* and up
                if [ $coreAlfrescoName != $coreName ]
                then
                    setOption 'solr.backup.dir' "$SOLR_BACKUP_DIR/$coreName/$coreAlfrescoName" "$CONFIG_FILE_CORE"
                else
                    setOption 'solr.backup.dir' "$SOLR_BACKUP_DIR/$coreName" "$CONFIG_FILE_CORE"
                fi
                CONFIG_FILE_SOLR_SCHEMA=$newCore/conf/schema.xml
                if [ $ALFRESCO_SOLR_SUGGESTER_ENABLED = true ]
                then
                    sed -i 's/.*\(<copyField source="suggest_\*" dest="suggest" \/>\).*/\1/g' "$CONFIG_FILE_SOLR_SCHEMA"
                else
                    sed -i 's/.*\(<copyField source="suggest_\*" dest="suggest" \/>\).*/<!--\1-->/g' "$CONFIG_FILE_SOLR_SCHEMA"
                fi
                if [ $ALFRESCO_SOLR_FACETABLE_CATEGORIES_ENABLED = true ]
                then
                    sed -i 's/\(.*<dynamicField.*name="\(category\|noderef\)@m_.*type="\)\(oldStandardAnalysis\)\(".*\)\(\/\)\(.*\)/\1identifier\4docValues="true" \/\6/g' "$CONFIG_FILE_SOLR_SCHEMA"
                    sed -i 's/\(.*<dynamicField.*name="\(category\|noderef\)@s_.*type="\)\(oldStandardAnalysis\)\(".*\)\(sortMissingLast="true"\)\(.*\)/\1identifier\4docValues="true"\6/g' "$CONFIG_FILE_SOLR_SCHEMA"
                fi

                setGlobalOptions "$CONFIG_FILE_CORE" $coreAlfrescoName

                escapeFile "$CONFIG_FILE_CORE"

                if [ $CUSTOM_SCHEMA = true ]
                then
                    echo "Will copy custom schema to shard $newCore/conf/schema.xml"
                    cp "$SOLR_INSTALL_HOME/schema.xml" $newCore/conf/schema.xml
                fi
                if [ $CUSTOM_RESOURCES = true ]
                then
                    echo "Copying custom resources to shard $newCore/conf/custom_resources/"
                    cp -r "$SOLR_INSTALL_HOME/custom_resources/" $newCore/conf/custom_resources/
                fi
            done
        elif [ $coreName = archive ]
        then
            createCoreStatically "archive" "$newCore"

            setOption 'alfresco.stores' "archive://SpacesStore" "$CONFIG_FILE_CORE"
            setOption 'enable.alfresco.tracking' "${ARCHIVE_ENABLE_TRACKING:-true}" "$CONFIG_FILE_CORE"
            setOption 'alfresco.index.transformContent' "${ARCHIVE_INDEX_CONTENT:-true}" "$CONFIG_FILE_CORE"

            setGlobalOptions "$CONFIG_FILE_CORE" archive
            escapeFile "$CONFIG_FILE_CORE"

            # SOLR_BACKUP_DIR only useful for ASS v2.0.2* and up
            if [ $SOLR_VERSION_MAJOR = 2 -a $SOLR_VERSION_REV != 0 -a $SOLR_VERSION_REV != 1 ]
            then
                setOption 'solr.backup.dir' "$SOLR_BACKUP_DIR/$coreName" "$CONFIG_FILE_CORE"
            fi
            if [ $CUSTOM_SCHEMA = true ]
            then
                cp "$SOLR_INSTALL_HOME/schema.xml" $newCore/conf/schema.xml
            fi
            if [ $CUSTOM_RESOURCES = true ]
            then
                echo "Copying custom resources to shard $newCore/conf/custom_resources/"
                cp -r "$SOLR_INSTALL_HOME/custom_resources/" $newCore/conf/custom_resources/
            fi
        elif [ $coreName = version ]
        then
            createCoreStatically "version" "$newCore"

            setOption 'alfresco.stores' "workspace://version2Store" "$CONFIG_FILE_CORE"

            setGlobalOptions "$CONFIG_FILE_CORE" version
            escapeFile "$CONFIG_FILE_CORE"

            if [ $CUSTOM_SCHEMA = true ]
            then
                cp "$SOLR_INSTALL_HOME/schema.xml" $newCore/conf/schema.xml
            fi
            if [ $CUSTOM_RESOURCES = true ]
            then
                echo "Copying custom resources to shard $newCore/conf/custom_resources/"
                cp -r "$SOLR_INSTALL_HOME/custom_resources/" $newCore/conf/custom_resources/
            fi
        else
            "Core $coreName not found"
        fi
    done
}

#follow http://docs.alfresco.com/5.2/tasks/solr6-install.html
echo "export SOLR_SOLR_DATA_DIR=${SOLR_DATA_DIR:-$SOLR_DATA_ROOT/index}" >>"$CONFIG_FILE_SOLR_START"
echo "export SOLR_SOLR_MODEL_DIR=${SOLR_MODEL_DIR:-$SOLR_DATA_ROOT/model}" >>"$CONFIG_FILE_SOLR_START"
echo "export SOLR_SOLR_CONTENT_DIR=${SOLR_CONTENT_DIR:-$SOLR_DATA_ROOT/contentstore}" >>"$CONFIG_FILE_SOLR_START"

if [ $ALFRESCO_SSL != none ]
then
    cp -r ${SOLR_DIR_ROOT}/keystore/* ${SOLR_DIR_ROOT}/templates/${TEMPLATE}/conf/
    
    setOption 'SOLR_SSL_KEY_STORE_TYPE' "JCEKS" "$CONFIG_FILE_SOLR_START"
    setOption 'SOLR_SSL_KEYSTORE_TYPE' "JCEKS" "$CONFIG_FILE_SOLR_START"
    setOption 'SOLR_SSL_TRUST_STORE_TYPE' "JCEKS" "$CONFIG_FILE_SOLR_START"
    setOption 'SOLR_SSL_KEY_STORE' "${SOLR_DIR_ROOT}/keystore/${SSL_KEY_STORE}" "$CONFIG_FILE_SOLR_START"
    setOption 'SOLR_SSL_KEY_STORE_PASSWORD' "$SSL_KEY_STORE_PASSWORD" "$CONFIG_FILE_SOLR_START"
    setOption 'SOLR_SSL_TRUST_STORE' "${SOLR_DIR_ROOT}/keystore/${SSL_TRUST_STORE}" "$CONFIG_FILE_SOLR_START"
    setOption 'SOLR_SSL_TRUST_STORE_PASSWORD' "$SSL_TRUST_STORE_PASSWORD" "$CONFIG_FILE_SOLR_START"
    setOption 'SOLR_SSL_NEED_CLIENT_AUTH' "true" "$CONFIG_FILE_SOLR_START"
    setOption 'SOLR_SSL_WANT_CLIENT_AUTH' "false" "$CONFIG_FILE_SOLR_START"
    setOption 'SOLR_SOLR_HOST' "$SOLR_HOST" "$CONFIG_FILE_SOLR_START"
    setOption 'SOLR_SOLR_PORT' "$PORT" "$CONFIG_FILE_SOLR_START"

    setJavaOption 'ssl-keystore.password' "-Dssl-keystore.password=$SSL_KEY_STORE_PASSWORD"
    setJavaOption 'ssl-keystore.aliases' "-Dssl-keystore.aliases=ssl-alfresco-ca,ssl-repo-client"
    setJavaOption 'ssl-keystore.ssl-alfresco-ca.password' "-Dssl-keystore.ssl-alfresco-ca.password=$SSL_KEY_STORE_PASSWORD"
    setJavaOption 'ssl-keystore.ssl-repo-client.password' "-Dssl-keystore.ssl-repo-client.password=$SSL_KEY_STORE_PASSWORD"
    setJavaOption 'ssl-truststore.password' "-Dssl-truststore.password=$SSL_TRUST_STORE_PASSWORD"
    setJavaOption 'ssl-truststore.aliases' "-Dssl-truststore.aliases=ssl-alfresco-ca,ssl-repo-client"
    setJavaOption 'ssl-truststore.ssl-alfresco-ca.password' "-Dssl-truststore.ssl-alfresco-ca.password=$SSL_TRUST_STORE_PASSWORD"
    setJavaOption 'ssl-truststore.ssl-repo-client.password' "-Dssl-truststore.ssl-repo-client.password=$SSL_TRUST_STORE_PASSWORD"
fi

# set tmp folder
JAVA_OPTS="${JAVA_OPTS} -Djava.io.tmpdir=${SOLR_INSTALL_HOME}/temp"

makeConfigs

user="solr"
# make sure backup folders exist and have the right permissions in case of mounts
for coreName in "${DEFAULT_CORES[@]}"
do
    mkdir -p "${SOLR_BACKUP_DIR}/$coreName"
    if [[ $(stat -c %U "${SOLR_BACKUP_DIR}/$coreName") != "$user" ]]
    then
        chown -hR "$user":"$user" "${SOLR_BACKUP_DIR}/$coreName"
    fi
done


# fix permissions for whole data folder in case of mounts
if [[ $(stat -c %U "${SOLR_DATA_ROOT}") != "$user" ]]
then
    chown -R "$user":"$user" "${SOLR_DATA_ROOT}"
fi
# fix permissions for config folders
chown -R "$user":"$user" "${SOLR_DIR_ROOT}"

echo "exec gosu ${user} ${SOLR_INSTALL_HOME}/solr/bin/solr start -f -m ${JAVA_XMX} -p ${PORT} -h ${SOLR_HOST} -s ${SOLR_DIR_ROOT} -a \"${JAVA_OPTS}\"" >"${SOLR_INSTALL_HOME}/startup.sh"

echo "Solr init done"
