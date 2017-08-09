# docker-nexus-backup

A container image for backing-up Sonatype Nexus Repository Manager data into GCP Cloud Storage.

[![Docker Repository on Quay](https://quay.io/repository/travelaudience/docker-nexus-backup/status "Docker Repository on Quay")](https://quay.io/repository/travelaudience/docker-nexus-backup)

## Introduction

Nexus Repository Manager can be configured to back-up its internal database on
a regular basis. However, this process does not take blob stores into account.
Furthermore, the back-ups are persisted in the local disk alone, meaning if
the disk is lost, the back-ups are lost too.

This tool addresses these two shortcomings by backing-up the `default` blob
store and then uploading everything to GCS, including the database back-up
Nexus previously created. This procedure is automatically triggered by
[`touching`](https://en.wikipedia.org/wiki/Touch_(Unix))ing
`${NEXUS_BACKUP_DIRECTORY}/.backup`.

When the back-up starts, a lock file is created so that no two backup processes
run simultaneously. This lock file is removed automatically after a successful
backup. A warning message is displayed whenever a lock file has been present for
more than twelve hours (meaning a failed backup), and the lock file is removed
so that further back-ups can be made.

## Run

The simplest way to run the container is to assume the default configuration
(check [below](#environment-variables) for the default configuration):

```bash
docker run --detach                                               \
           --name nexus-backup                                    \
           --volume /path/to/nexus-data:/nexus-data               \
           --volume /path/to/nexus-data-backup:/nexus-data/backup \
           quay.io/travelaudience/docker-nexus-backup:1.2.0
```

You can change, for example, the repositories which to lock during backup and
the target Google Cloud Storage bucket by specifing the correct values as
environment variables:

```bash
docker run --detach \
           --env OFFLINE_REPOS="docker-hosted maven-central maven-public maven-releases maven-snapshots" \
           --env TARGET_BUCKET="gs://my-fancy-bucket/" \
           --name nexus-backup \
           --volume /path/to/nexus-data:/nexus-data \
           --volume /path/to/nexus-data-backup:/nexus-data/backup \
           quay.io/travelaudience/docker-nexus-backup:1.2.0
```

## Inside Google Container Engine

Your Google Container Engine cluster **must be** created with Cloud Storage read-write
permissions enabled (`https://www.googleapis.com/auth/devstorage.read_write` scope).

## Outside Google Container Engine

If you're running this image, or any other container image based on this,
outside GKE you will need to create a [service account](https://cloud.google.com/iam/docs/service-accounts)
with the "_Storage Object Creator_" and "_Storage Object Viewer_" permissions,
download the newly furnished private key file in JSON format, mount it in the
container and specify the mount path using the `CLOUD_IAM_SERVICE_ACCOUNT_KEY_PATH`
environment variable.

## Environment Variables

This image can be configured by means of environment variables. You will most
probably want to customize `NEXUS_AUTHORIZATION`, `NEXUS_LOCAL_HOST_PORT` and
`TARGET_BUCKET` to suit your use case, while most other environment variables
will require no changes.

| Variable                             | Description                                                                                   | Default                                                     |
|--------------------------------------|-----------------------------------------------------------------------------------------------|-------------------------------------------------------------|
| `CLOUD_IAM_SERVICE_ACCOUNT_KEY_PATH` | (**Optional**) The path to a service account key file with which to authenticate against GCS. | (empty)                                                     |
| `NEXUS_AUTHORIZATION`                | The authorization header to use when calling the Nexus API.                                   | `Basic YWRtaW46YWRtaW4xMjMK`                                |
| `NEXUS_BACKUP_DIRECTORY`             | The directory to which the Nexus 'backup-2' task will produce its output.                     | `/nexus-data/backup`                                        |
| `NEXUS_DATA_DIRECTORY`               | The Nexus data directory.                                                                     | `/nexus-data`                                               |
| `NEXUS_LOCAL_HOST_PORT`              | The host and port at which Nexus can be reached.                                              | `localhost:8081`                                            |
| `OFFLINE_REPOS`                      | The names of the repositories must be taken down to achieve a consistent backup.              | `maven-central maven-public maven-releases maven-snapshots` |
| `TARGET_BUCKET`                      | The name of the GCS bucket to which the resulting backups will be uploaded.                   | `gs://nexus-backup`                                         |
| `GRACE_PERIOD`                       | The amount of time in seconds to wait between stopping repositories and starting the upload.  | `60`                                                        |
