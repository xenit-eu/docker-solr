## Solr Backup and Restore

When using this backup/restore mechanism, Solr's replication handler is using Caringo Swarm as the storage layer for the backups. The implementation of the new backend repository is [here](https://github.com/xenit-eu/solr-backup).

Taking a backup is trigerred by a [custom image](https://bitbucket.org/xenit/docker-solrbackup/src/master/), via a [central scheduler](https://github.com/crazy-max/swarm-cronjob). Cron expression is specified via container labels. Depending on an environment variable, backup can be taken only on first instance of solr service. Once backup is done successfully, it is marked as such by appending newly created snapshot to a “success” file in the bucket in Swarm.

Restore is done via an init script in solr image, which checks the need of restore (variable + existence of index), starts solr without tracking, does the restore and restarts solr with tracking enabled. Snapshot's name is taken as the last line from the "success" file in Swarm.

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


### Known improvements

Currently there is some duplication between variables used by the replication handler and the ones used by the restore script. Different methods are being used to specify variables: Java system properties versus environment variables. They could be unified.

While the replication handler is communicating to Caringo Swarm via the S3 protocol, the file with successful snapshots is uploaded / downloaded from Swarm via the scsp protocol. This could be handled more uniformly.

### Communication via SSL
In case communication to Solr requires mtls, certificates needed should be included in the backup container and in solr image. A set of default certificates is provided.