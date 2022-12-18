#!/bin/bash

# A script for uploading a single binary file to an Artifactory generic repository
# and then run a loop of parallel downloads of this file for a given number of iterations.

SCRIPT_NAME=$0

# Set some defaults
ART_URL=http://localhost:8082/artifactory
REPO=example-repo-local
SIZE_MB=1
USER=admin
PASS=password
THREADS=1
ITERATIONS=1


######### Functions #########

errorExit () {
    echo -e "\nERROR: $1\n"
    exit 1
}

usage () {
    cat << END_USAGE

Usage: ${SCRIPT_NAME} <options>

-l | --url                             : Artifactory URL                            (defaults to $ART_URL)
-u | --user                            : Artifactory user                           (defaults to $USER)
-p | --pass | --password               : Artifactory password, API key or token     (defaults to $PASS)
-r | --repo | --repository             : Repository                                 (defaults to $REPO)
-s | --size                            : Size in MB                                 (defaults to ${SIZE_MB})
-i | --iterations                      : Number of download iterations              (defaults to ${ITERATIONS})
-t | --threads                         : Number of download threads per iteration   (defaults to ${THREADS})
-h | --help                            : Show this usage.
--no-headers                           : Don't print headers line.

Examples:
========
Upload a 10 MB file and download for 100 times with 5 parallel connections to https://server.company.org:
$ ${SCRIPT_NAME} --url https://server.company.org \
                 --user admin --password password1x \
                 --repo generic-tests \
                 --size 10 \
                 --iterations 100 \
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
            -r | --repo | --repository)
                REPO="$2"
                shift 2
            ;;
            -s | --size)
                SIZE_MB="$2"
                shift 2
            ;;
            -i | --iterations)
                ITERATIONS="$2"
                shift 2
            ;;
            -t | --threads)
                THREADS="$2"
                shift 2
            ;;
            -h | --help)
                usage
                exit 0
            ;;
            *)
                usage
            ;;
        esac
    done
}

createAndUploadGenericFile () {
    local test_file="test${SIZE_MB}MB"
    FULL_PATH="${ART_URL}/${REPO}/${test_file}"

    # Create a unique binary, generic file
    echo "Creating a $SIZE_MB MB file ${test_file}"
    dd if=/dev/urandom of=${test_file} bs=1048576 count=${SIZE_MB} > /dev/null 2>&1 || errorExit "Creating file ${test_file} failed"

    # Upload file
    echo "Uploading ${test_file} to ${FULL_PATH}"
    curl -f -s -u ${USER}:${PASS} -X PUT -T ./${test_file} "${FULL_PATH}" -o /dev/null || errorExit "Uploading ${test_file} to ${FULL_PATH} failed"

    # Remove file
    echo "Deleting ${test_file}"
    rm -f ${test_file} || errorExit "Deleting $test_file failed"
}

downloadLoop () {
    local pid_array=()

    echo "Starting the download loop"
    for ((i=1; i <= ${ITERATIONS}; i++)); do
        echo "--- Download iteration ${i}. Starting ${THREADS} parallel threads"
        for ((j=1; j <= ${THREADS}; j++)); do
            curl -L -s -f -u ${USER}:${PASS} -X GET "${FULL_PATH}" -o /dev/null &
            pid_array[$j]=$!
        done
        echo "Waiting for ${#pid_array[@]} processes (${pid_array[@]})"
        wait
    done
}

main () {
    processOptions $@
    createAndUploadGenericFile
    downloadLoop
}

main $@
