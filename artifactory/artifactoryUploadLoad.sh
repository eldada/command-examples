#!/bin/bash

# Default parameters
SCRIPT_NAME=$0
SCRIPT_DIR=$(dirname "${SCRIPT_NAME}")
UPLOAD_LOG="${SCRIPT_DIR}/${SCRIPT_NAME}.log"

NUM_FILES=100
FILE_SIZE_KB=10
DEST_DIR=${SCRIPT_DIR}/testFiles
UPLOAD_DURATION=20
THREADS=5

ART_URL="http://localhost"
REPO_NAME="example-repo-local"
ARTIFACTORY_USER="admin"
ARTIFACTORY_PASSWORD="password"

CLEANUP=true

######### Functions #########

errorExit () {
    echo -e "\nERROR: $1\n"
    exit 1
}

usage () {
    cat <<END_USAGE
Generate random unique binary files and upload them to Artifactory with a specified number of threads for a given duration.

Usage: ${SCRIPT_NAME} <options>

-l | --url                             : Artifactory URL                            (defaults to ${ART_URL})
-u | --user | --username               : Artifactory user                           (defaults to ${USER})
-p | --pass | --password               : Artifactory password, API key or token     (defaults to ${PASS})
-r | --repo                            : Repository name                            (defaults to ${REPO_NAME})
-s | --size                            : Size in KB                                 (defaults to ${FILE_SIZE_KB})
-n | --number_of_files                 : Number of files to generate                (defaults to ${NUM_FILES})
-d | --duration                        : Duration of test in seconds                (defaults to ${UPLOAD_DURATION})
-t | --threads                         : Number of parallel upload threads          (defaults to ${THREADS})
-c | --cleanup                         : Cleanup generated files and logs           (defaults to ${CLEANUP})
-h | --help                            : Show this usage.

Examples:
========
# Test with all defaults - downloads and uploads
$ ${SCRIPT_NAME}

# Create 1000 files of size 10KB and upload them with 5 threads for 180 seconds
$ ${SCRIPT_NAME} --url ${ART_URL} \\
                 --user admin --password password \\
                 --number_of_files 1000 \\
                 --size 10 \\
                 --duration 180 \\
                 --threads 5
END_USAGE

    exit 1
}

processOptions () {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l | --url)
                ART_URL="$2"
                shift 2
            ;;
            -u | --user | --username)
                USER="$2"
                shift 2
            ;;
            -p | --pass | --password)
                PASS="$2"
                shift 2
            ;;
            -r | --repo )
                REPO_NAME="$2"
                shift 2
            ;;
            -n | --number_of_files)
                NUM_FILES="$2"
                shift 2
            ;;
            -s | --size)
                FILE_SIZE_KB="$2"
                shift 2
            ;;
            -d | --duration)
                UPLOAD_DURATION="$2"
                shift 2
            ;;
            -t | --threads)
                THREADS="$2"
                shift 2
            ;;
            -c | --cleanup)
                CLEANUP="$2"
                shift 2
            ;;
            -h | --help)
                usage
            ;;
            *)
                usage
            ;;
        esac
    done

    # Add the artifactory context to the ART_URL if missing
    if [[ ! ${ART_URL} =~ \/artifactory\/?$ ]]; then
        ART_URL="${ART_URL%/}"
        ART_URL="${ART_URL}/artifactory"
    fi
}

testArtifactory () {
    echo -n "Check Artifactory readiness... "
    jf rt ping --url="${ART_URL}" --user="${ARTIFACTORY_USER}" --password="${ARTIFACTORY_PASSWORD}" || errorExit "Artifactory readiness failed"
    echo
}

generateFiles () {
    echo "Generating ${NUM_FILES} unique binary files of size ${FILE_SIZE_KB} KB in ${DEST_DIR}"

    # Delete the destination directory if it exists and create a new one
    [[ -d "$DEST_DIR" ]] && rm -rf "$DEST_DIR"
    mkdir -p "$DEST_DIR"

    for ((i=1; i<=NUM_FILES; i++)); do
        # Generate a unique file name
        FILE_NAME="$DEST_DIR/file_$i.bin"

        FILE_SIZE=$((FILE_SIZE_KB * 1024)) # Convert KB to bytes

        # Generate a random binary file of the given size
        head -c "$FILE_SIZE" /dev/urandom > "$FILE_NAME"
    done

    echo "Generating the files complete"
}

uploadFiles () {
    echo "Uploading the generated files to Artifactory with ${THREADS} threads for a duration of ${UPLOAD_DURATION} seconds"

    # Start the upload process
    START_TIME=$(date +%s)
    END_TIME=$((START_TIME + UPLOAD_DURATION))
    CURRENT_TIME=$(date +%s)

    ROUND=1
    while [ "${CURRENT_TIME}" -lt "${END_TIME}" ]; do
      jf rt upload \
        --url="${ART_URL}" \
        --user="${ARTIFACTORY_USER}" \
        --password="${ARTIFACTORY_PASSWORD}" \
        --flat=true \
        --quiet=true \
        --threads="${THREADS}" \
        "${DEST_DIR}/*" \
        "${REPO_NAME}/" > "${UPLOAD_LOG}" 2>&1
        if [[ $? -ne 0 ]]; then
            errorExit "Upload failed (elapsed time: $((CURRENT_TIME - START_TIME)) seconds). Check ${SCRIPT_NAME}.log"
        fi
        CURRENT_TIME=$(date +%s)
        echo "Upload round ${ROUND} completed successfully (elapsed time: $((CURRENT_TIME - START_TIME)) seconds)"

        ROUND=$((ROUND + 1))
    done

    echo "Upload cycle completed. Total uploads completed: $((ROUND * NUM_FILES))"
}

cleanup () {
    if [[ "${CLEANUP}" =~ true ]]; then
        echo "Cleaning up the generated files and logs"
        rm -rf "${DEST_DIR}" "${UPLOAD_LOG}"
    else
        echo "Skipping cleanup. Files and logs are retained in ${DEST_DIR} and ${UPLOAD_LOG}"
    fi
}

main () {
    # Check if JFrog CLI is installed
    if ! jf -v &> /dev/null; then
        errorExit "JFrog CLI could not be found. Please install it and try again"
    fi

    # Process command line options
    processOptions "$@"

    # Check Artifactory readiness
    testArtifactory

    # Generate test files
    generateFiles

    # Upload files to Artifactory
    uploadFiles

    # Cleanup
    cleanup
}

main "$@"
