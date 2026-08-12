#!/bin/bash
echo "--- Creating S3 bucket for Solr backups ---"
awslocal s3 mb s3://bucket

# The two search services generations resolve a backup location differently: 2.0.x appends the core
# name, 1.4.x does not. Their solr logs show it plainly:
#   2.0.8.2  //opt//alfresco-search-services//data//solr6Backup//alfresco
#   1.4.3.4  //opt//alfresco-search-services//data//solr6Backup//
# Rather than teach this script which version it is serving, seed both keys so either generation
# finds the snapshot under the name the tests ask for.
BASE=s3://bucket/opt/alfresco-search-services/data/solr6Backup
SNAPSHOT=snapshot.my-alfresco-backup-20251006

echo "--- Uploading Solr snapshot 'my-alfresco-backup-20251006' to S3 (1.4.x layout) ---"
awslocal s3 sync /backups/snapshot "$BASE/$SNAPSHOT"

echo "--- Uploading Solr snapshot 'my-alfresco-backup-20251006' to S3 (2.0.x layout, core in path) ---"
awslocal s3 sync /backups/snapshot "$BASE/alfresco/$SNAPSHOT"
