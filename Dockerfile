FROM alpine:3.10

LABEL maintainer devops@travelaudience.com

# The path to the Cloud IAM service account to use when uploading backups.
ENV CLOUD_IAM_SERVICE_ACCOUNT_KEY_PATH ""
# The authorization header to use when calling the Nexus API.
ENV NEXUS_AUTHORIZATION "Basic YWRtaW46YWRtaW4xMjMK"

# The directory to which the Nexus 'backup-2' task will produce its output.
ENV NEXUS_BACKUP_DIRECTORY="/nexus-data/backup"

# The Nexus data directory.
ENV NEXUS_DATA_DIRECTORY="/nexus-data"

# The pod-local host and port at which Nexus can be reached.
ENV NEXUS_LOCAL_HOST_PORT "localhost:8081"

# The names of the repositories we need to take down to achieve a consistent backup.
ENV OFFLINE_REPOS "maven-central maven-public maven-releases maven-snapshots"

# The name of the GCS bucket to which the resulting backups will be uploaded.

ENV TARGET_BUCKET "gs://nexus-backup"
# The amount of time in seconds to wait between stopping repositories and starting the upload.
ENV GRACE_PERIOD "60"

WORKDIR /tmp

RUN apk add --no-cache --update bash ca-certificates curl inotify-tools python openssl \
    && wget -O google-cloud-sdk.tar.gz https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-255.0.0-linux-x86_64.tar.gz \
    && tar xzf google-cloud-sdk.tar.gz \
    && rm google-cloud-sdk.tar.gz \
    && ./google-cloud-sdk/install.sh --command-completion true --override-components gcloud gsutil --path-update true --quiet --rc-path /root/.bashrc --usage-reporting false

ADD docker-entrypoint.sh /docker-entrypoint.sh
ADD /scripts/start-repository.groovy /scripts/start-repository.groovy
ADD /scripts/stop-repository.groovy /scripts/stop-repository.groovy

ENTRYPOINT ["/docker-entrypoint.sh"]
