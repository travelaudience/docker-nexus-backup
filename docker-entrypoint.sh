#!/bin/bash

set -o pipefail

source /root/.bashrc

function backup {
    local TIMESTAMP;

    # The timestamp of the backup (we chose ISO-8601 for clarity).
    TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    # Make sure every Groovy script necessary for backup is installed.
    find /scripts -name "*.groovy" | while read -r FILE;
    do
        ensure_groovy_script "${FILE}";
    done

    echo "==> Attempting to stop repositories.";
    manage_repos stop

    echo "==> Sleeping for ${GRACE_PERIOD} seconds."
    sleep "${GRACE_PERIOD}"

    echo "==> Attempting to backup the 'default' blobstore."
    tar c "${NEXUS_DATA_DIRECTORY}/blobs/default/" | gsutil cp - "${TARGET_BUCKET}/${TIMESTAMP}/blobstore.tar"

    local EXIT_CODE_1=$?

    if [ ${EXIT_CODE_1} -ne 0 ]; then
        echo "(!) Couldn't backup the blobstore. Manual intervention is advised."
    else
        echo "(✓) Blobstore successfully backed-up."
    fi

    echo "==> Attempting to backup the Nexus databases."
    tar c "${NEXUS_BACKUP_DIRECTORY}/" | gsutil cp - "${TARGET_BUCKET}/${TIMESTAMP}/databases.tar"

    local EXIT_CODE_2=$?

    if [ ${EXIT_CODE_2} -ne 0 ]; then
        echo "(!) Couldn't backup the databases. Manual intervention is advised."
    else
        find "${NEXUS_BACKUP_DIRECTORY}" -name "*.bak" -exec rm {} \; # Cleanup leftovers so that they don't get picked up next time.
        echo "(✓) Databases successfully backed-up."
    fi

    echo "==> Attempting to start repositories."
    manage_repos start
}

function ensure_groovy_script {
    local BODY;
    local NAME;

    # Remove line breaks from the script.
    BODY=$(tr -d '\n' < "${1}")
    # Get the script's filename without extension.
    NAME=$(basename "${1}" .groovy)

    # Delete any previously existing script.
    curl -H "Authorization: ${NEXUS_AUTHORIZATION}" \
      -o /dev/null \
      -s \
      -w "${http_code}" \
      -X DELETE \
      "${NEXUS_LOCAL_HOST_PORT}/service/siesta/rest/v1/script/${NAME}/"

    # Install the script.
    curl -d "{\"name\":\"${NAME}\",\"type\":\"groovy\",\"content\":\"${BODY}\"}" \
      -H "Authorization: ${NEXUS_AUTHORIZATION}" \
      -H 'Content-Type: application/json' \
      -s \
      -S \
      -X POST \
      "${NEXUS_LOCAL_HOST_PORT}/service/siesta/rest/v1/script/"  
}

function manage_repos { # Supported actions are 'start' and 'stop'.
    local REPOS=($OFFLINE_REPOS)
    
    for repo in "${REPOS[@]}";
    do
       curl -d "${repo}" \
            -H "Authorization: ${NEXUS_AUTHORIZATION}" \
            -H "Content-Type: text/plain" \
            -s \
            -X POST \
            "${NEXUS_LOCAL_HOST_PORT}/service/siesta/rest/v1/script/${1}-repository/run" > /dev/null
    done
}

function maybe_start_backup {
    echo "==> Checking whether Nexus is reachable."
    nc -z -w1 "${NEXUS_LOCAL_HOST_PORT}"

    local EXIT_CODE=$?

    if [ ${EXIT_CODE} -ne 0 ]; then
        echo "(!) Nexus isn't responding. Maybe it's starting up or a backup procedure is in place?"
        return 1;
    fi

    echo "==> Starting the backup procedure @ $(date)."

    backup & wait

    echo "==> Finished the backup procedure @ $(date)."
}

if [[ -z "${NEXUS_AUTHORIZATION}" ]];
then
    echo "Nexus authorization token is not defined."
    exit 1
fi

if [[ ! -d "${NEXUS_BACKUP_DIRECTORY}" ]];
then
    echo "Backup directory not present. Is the volume mounted?"
    exit 1
fi

if [[ ! -d "${NEXUS_DATA_DIRECTORY}" ]];
then
    echo "Data directory not present. Is the volume mounted?"
    exit 1
fi

if [[ -z "${NEXUS_LOCAL_HOST_PORT}" ]];
then
    echo "Nexus pod-local host and port are not defined."
    exit 1
fi

if [[ -z "${TARGET_BUCKET}" ]];
then
    echo "Target GCS bucket is not defined."
    exit 1
fi

if [[ -z "${GRACE_PERIOD}" ]];
then
    echo "Grace period is not defined."
    exit 1
fi

if [[ -z "${TRIGGER_FILE}" ]];
then
    echo "Trigger file is not defined."
    exit 1
fi

inotifywait -e attrib,create --format "%f" -m -q "${NEXUS_BACKUP_DIRECTORY}" | while read -r FILE
do
    if [[ "${FILE}" == "${TRIGGER_FILE}" ]];
    then
        maybe_start_backup
    fi
done
