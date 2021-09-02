## Solr Backup and Restore

When using this backup/restore mechanism, Solr's replication handler is using Caringo Swarm as the storage layer for the backups. The implementation of the new backend repository is [here](https://github.com/xenit-eu/solr-backup).

Taking a backup is trigerred by a [custom image](https://bitbucket.org/xenit/docker-solrbackup/src/master/), via a [central scheduler](https://github.com/crazy-max/swarm-cronjob). Cron expression is specified via container labels. Depending on an environment variable, backup can be taken only on first instance of solr service. 

Restore is done via an init script in solr image, which checks the need of restore (variable + existence of index), starts solr without tracking, does the restore and restarts solr with tracking enabled. Snapshot's name can be specified via a variable or detected as the latest snapshot in the bucket.

![alt Architectural diagram](./SolrBackup.svg)



| Variable                    | Default                           | Comments                               |
| --------------------------- | --------------------------------- | -------------------------------------- |
| RESTORE_FROM_BACKUP         |                                   | Whether to attempt a restore from backup at startup |
| RESTORE_BACKUP_NAME         |                                   | If provided, restores from that specific snapshot. If not provided, it is inferred from the "success" file |
| BACKUP_USERNAME             |                                   | Caringo Swarm username |
| BACKUP_PASSWORD             |                                   | Caringo Swarm password |
| BACKUP_ENDPOINT             |                                   | Caringo Swarm endpoint |
| BACKUP_DOMAIN               |                                   | Caringo Swarm domain |
| BACKUP_BUCKET               |                                   | Caringo Swarm bucket |
| JAVA_OPTS_S3_ENDPOINT       |                                   | Caringo Swarm S3 endpoint |
| JAVA_OPTS_S3_BUCKET_NAME    |                                   | Caringo Swarm S3 bucket |
| AWS_ACCESS_KEY_ID           |                                   | Caringo Swarm S3 access key |
| AWS_SECRET_KEY              |                                   | Caringo Swarm S3 secret key |


### Communication via SSL
In case communication to Solr requires mtls, certificates needed should be included in the backup container and in solr image. A set of default certificates is provided.