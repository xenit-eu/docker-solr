#!/bin/bash
echo "--- Creating S3 bucket for Solr backups ---"
awslocal s3 mb s3://bucket

# The key has to match what solr reads for location=s3:///opt/... , i.e. no core name in the path.
# The previous "alfresco/" segment put the snapshot somewhere no restore ever looked.
echo "--- Uploading Solr snapshot 'my-alfresco-backup-20251006' to S3 ---"
awslocal s3 sync /backups/snapshot s3://bucket/opt/alfresco-search-services/data/solr6Backup/snapshot.my-alfresco-backup-20251006
