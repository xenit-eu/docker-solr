#!/bin/bash

# should get environment var from docker image / container:
# ${CATALINA_HOME} = /usr/local/tomcat
# SOLR_DIR_ROOT=${SOLR_DIR_ROOT:-'/opt/alfresco/solr4'}

set -e

echo "Solr init start"

SOLR_DATA_ROOT=${SOLR_DATA_ROOT:-'/opt/alfresco/alf_data/solr4'}
DIR_ROOT=${DIR_ROOT:-'/opt/alfresco/alf_data'}

CONFIG_FILE_SOLR_WORKSPACE=$SOLR_DIR_ROOT'/workspace-SpacesStore/conf/solrcore.properties'
CONFIG_FILE_SOLR_ARCHIVE=$SOLR_DIR_ROOT'/archive-SpacesStore/conf/solrcore.properties'
TOMCAT_CONFIG_FILE=${CATALINA_HOME}'/bin/setenv.sh'
TOMCAT_SERVER_FILE=${CATALINA_HOME}'/conf/server.xml'

ALFRESCO_SSL=${ALFRESCO_SSL:-'https'}

ALFRESCO_SOLR_SUGGESTER_ENABLED=${ALFRESCO_SOLR_SUGGESTER_ENABLED:-'true'}
ALFRESCO_SOLR_FACETABLE_CATEGORIES_ENABLED=${ALFRESCO_SOLR_FACETABLE_CATEGORIES_ENABLED:-'false'}

# sets an Alfresco / Tomcat parameter as a JAVA_OPTS parameter
# the key is ignored, the value should contain the "-D" flag if it's a property
function setJavaOption {
    JAVA_OPTS="$JAVA_OPTS $2"
}

function setOption {
    if grep --quiet -e "$1\s*=" "$3"; then
        # replace option
        sed -i "s#^\($1\s*=\s*\).*\$#\1$2#" $3
	    sed -i "s#^\#\($1\s*=\s*\).*\$#\1$2#" $3
        if (( $? )); then
            echo "setOption failed (replacing option $1=$2 in $3)"
            exit 1
        fi
    else
        # add option if it does not exist
        echo "$1=$2" >> $3
    fi
}

function setGlobalOptions {
    file=$1
    coreName=$2
    IFS=$'\n'
    for i in `env`
    do
        if [[ $i == GLOBAL_WORKSPACE_* ]]
        then
            if [ $coreName = alfresco ]
	        then
                key=`echo $i | cut -d '=' -f 1 | cut -d '_' -f 3-`
                value=`echo $i | cut -d '=' -f 2-`
                setOption $key $value "$file"
            fi
        elif [[ $i == GLOBAL_ARCHIVE_* ]]
        then
            if [ $coreName = archive ]
	        then
                key=`echo $i | cut -d '=' -f 1 | cut -d '_' -f 3-`
                value=`echo $i | cut -d '=' -f 2-`
                setOption $key $value "$file"
            fi
        elif [[ $i == GLOBAL_* ]]
        then
           key=`echo $i | cut -d '=' -f 1 | cut -d '_' -f 2-`
           value=`echo $i | cut -d '=' -f 2-`
           setOption $key $value "$file"
        fi
    done
}

# workspace core file might not exist (if sharded index)
if [ -f "$CONFIG_FILE_SOLR_WORKSPACE" ]
then
  setOption 'alfresco.host' "${ALFRESCO_HOST:-alfresco}" "$CONFIG_FILE_SOLR_WORKSPACE"
  setOption 'alfresco.port' "${ALFRESCO_PORT:-8080}" "$CONFIG_FILE_SOLR_WORKSPACE"
  setOption 'alfresco.port.ssl' "${ALFRESCO_PORT_SSL:-8443}" "$CONFIG_FILE_SOLR_WORKSPACE"
  setOption 'alfresco.secureComms' "${ALFRESCO_SSL:-https}" "$CONFIG_FILE_SOLR_WORKSPACE"
  setOption 'enable.alfresco.tracking' "${ALFRESCO_ENABLE_TRACKING:-true}" "$CONFIG_FILE_SOLR_WORKSPACE"
  setOption 'alfresco.index.transformContent' "${ALFRESCO_INDEX_CONTENT:-true}" "$CONFIG_FILE_SOLR_WORKSPACE"
  setOption 'alfresco.corePoolSize' "${ALFRESCO_CORE_POOL_SIZE:-8}" "$CONFIG_FILE_SOLR_WORKSPACE"
  setOption 'alfresco.doPermissionChecks' "${ALFRESCO_DO_PERMISSION_CHECKS:-true}" "$CONFIG_FILE_SOLR_WORKSPACE"
  setOption 'solr.suggester.enabled' "${ALFRESCO_SOLR_SUGGESTER_ENABLED:-true}" "$CONFIG_FILE_SOLR_WORKSPACE"

  CONFIG_FILE_SOLR_SCHEMA=$SOLR_DIR_ROOT'/workspace-SpacesStore/conf/schema.xml'
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

  setGlobalOptions "$CONFIG_FILE_SOLR_WORKSPACE" alfresco
fi

if [ -f "$CONFIG_FILE_SOLR_ARCHIVE" ]
then
  setOption 'alfresco.host' "${ALFRESCO_HOST:-alfresco}" "$CONFIG_FILE_SOLR_ARCHIVE"
  setOption 'alfresco.port' "${ALFRESCO_PORT:-8080}" "$CONFIG_FILE_SOLR_ARCHIVE"
  setOption 'alfresco.port.ssl' "${ALFRESCO_PORT_SSL:-8443}" "$CONFIG_FILE_SOLR_ARCHIVE"
  setOption 'alfresco.secureComms' "${ALFRESCO_SSL:-https}" "$CONFIG_FILE_SOLR_ARCHIVE"
  setOption 'enable.alfresco.tracking' "${ARCHIVE_ENABLE_TRACKING:-true}" "$CONFIG_FILE_SOLR_ARCHIVE"
  setOption 'alfresco.index.transformContent' "${ARCHIVE_INDEX_CONTENT:-true}" "$CONFIG_FILE_SOLR_ARCHIVE"

  setGlobalOptions "$CONFIG_FILE_SOLR_ARCHIVE" archive
fi

if [ $ALFRESCO_SSL = none ]
then
sed -i '/<Connector port="\${TOMCAT_PORT_SSL}" URIEncoding="UTF-8" protocol="org.apache.coyote.http11.Http11Protocol" SSLEnabled="true"/,+5d' $TOMCAT_SERVER_FILE
fi


setJavaOption "defaults" "-Dfile.encoding=UTF-8"

### DEPRECATED
# for backwards compatibility with ansible-role-solr we keep the old options as well
# should be removed once ALFREDOPS-223 is resolved and rolled-out
   if [[ -n $SOLR_PORT ]]
    then
        TOMCAT_PORT=$SOLR_PORT
    fi

    if [[ -n $SOLR_PORT_SSL ]]
    then
        TOMCAT_PORT_SSL=$SOLR_PORT_SSL
    fi
setJavaOption 'TOMCAT_PORT' '-DTOMCAT_PORT='${TOMCAT_PORT:-8080}
setJavaOption 'TOMCAT_PORT_SSL' '-DTOMCAT_PORT_SSL='${TOMCAT_PORT_SSL:-8443}
### end DEPRECATED

setJavaOption 'SSL_TRUST_STORE' "-DSSL_TRUST_STORE=${SSL_TRUST_STORE:-'ssl.truststore'}"
setJavaOption 'SSL_TRUST_STORE_PASSWORD' "-DSSL_TRUST_STORE_PASSWORD=${SSL_TRUST_STORE_PASSWORD:-'kT9X6oe68t'}"
setJavaOption 'SSL_KEY_STORE' "-DSSL_KEY_STORE=${SSL_KEY_STORE:-'ssl.keystore'}"
setJavaOption 'SSL_KEY_STORE_PASSWORD' "-DSSL_KEY_STORE_PASSWORD=${SSL_KEY_STORE_PASSWORD:-'kT9X6oe68t'}"


echo "JAVA_OPTS=\"$JAVA_OPTS\"" >$TOMCAT_CONFIG_FILE
echo "export JAVA_OPTS" >> $TOMCAT_CONFIG_FILE

user="tomcat"
# make sure backup folders exist and have the right permissions in case of mounts
  for solrCoreName in alfresco archive
  do
      mkdir -p "${DIR_ROOT}/solr4Backup/$solrCoreName"
      if [[ $(stat -c %U "${DIR_ROOT}/solr4Backup/$solrCoreName") != "$user" ]]
	  then
	    chown -hR "$user":"$user" "${DIR_ROOT}/solr4Backup/$solrCoreName"
	  fi
  done

# fix permissions for whole data folder in case of mounts
if [[ $(stat -c %U /opt/alfresco/alf_data) != "$user" ]]
 then
    chown -R "$user":"$user" /opt/alfresco/alf_data
 fi
# fix permissions for index folder in case of mounts
if [[ -d "${SOLR_DATA_ROOT}" ]] && [[ $(stat -c %U "${SOLR_DATA_ROOT}") != $user ]]
 then
    chown -R "$user":"$user" "${SOLR_DATA_ROOT}"
 fi
# fix permissions for config folders
chown -R "$user":"$user" "${SOLR_DIR_ROOT}"

echo "Solr init done"
