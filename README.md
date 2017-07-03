# docker-nexus-backup

A container image for backing-up Sonatype Nexus Repository Manager data into GCP Cloud Storage.

[![Docker Repository on Quay](https://quay.io/repository/travelaudience/docker-nexus-backup/status "Docker Repository on Quay")](https://quay.io/repository/travelaudience/docker-nexus-backup)

## Run

The simplest way to run the container is to assume the default configuration
(check [below](#environment-variables) for the default configuration):

```text
docker run --detach                                               \
           --name nexus-backup                                    \
           --volume /path/to/nexus-data:/nexus-data               \
           --volume /path/to/nexus-data-backup:/nexus-data/backup \
           quay.io/travelaudience/docker-nexus-backup:1.0.0
```

You can change, for example, the repositories which to lock during backup and
the target Google Cloud Storage bucket by specifing the correct values as
environment variables:

```text
docker run --detach \
           --env OFFLINE_REPOS="docker-hosted maven-central maven-public maven-releases maven-snapshots" \
           --env TARGET_BUCKET="gs://my-fancy-bucket/" \
           --name nexus-backup \
           --volume /path/to/nexus-data:/nexus-data \
           --volume /path/to/nexus-data-backup:/nexus-data/backup \
           quay.io/travelaudience/docker-nexus-backup:1.0.0
```

## Environment Variables

This image can be configured by means of environment variables. You will most
probably want to customize `NEXUS_AUTHORIZATION`, `NEXUS_LOCAL_HOST_PORT` and
`TARGET_BUCKET` to suit your use case, while most other environment variables
will require no changes.

| Variable                 | Description                                                                                  | Default                                                     |
|--------------------------|----------------------------------------------------------------------------------------------|-------------------------------------------------------------|
| `NEXUS_AUTHORIZATION`    | The authorization header to use when calling the Nexus API.                                  | `Basic YWRtaW46YWRtaW4xMjMK`                                |
| `NEXUS_BACKUP_DIRECTORY` | The directory to which the Nexus 'backup-2' task will produce its output.                    | `/nexus-data/backup`                                        |
| `NEXUS_DATA_DIRECTORY`   | The Nexus data directory.                                                                    | `/nexus-data`                                               |
| `NEXUS_LOCAL_HOST_PORT`  | The host and port at which Nexus can be reached.                                             | `localhost:8081`                                            |
| `OFFLINE_REPOS`          | The names of the repositories must be taken down to achieve a consistent backup.             | `maven-central maven-public maven-releases maven-snapshots` |
| `TARGET_BUCKET`          | The name of the GCS bucket to which the resulting backups will be uploaded.                  | `gs://nexus-backup`                                         |
| `GRACE_PERIOD`           | The amount of time in seconds to wait between stopping repositories and starting the upload. | `60`                                                        |
| `TRIGGER_FILE`           | The name of the file used to trigger the backup procedure.                                   | `.backup`                                                   |