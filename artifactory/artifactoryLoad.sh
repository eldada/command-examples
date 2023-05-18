#!/bin/bash

# A script for running parallel processes of the artifactoryBenchmark.sh script to create high load

SCRIPT_NAME=$0
SCRIPT_DIR=$(dirname ${SCRIPT_NAME})
ART_BENCH_SCRIPT=${SCRIPT_DIR}/artifactoryBenchmark.sh
LOGS_DIR="${SCRIPT_DIR}/${SCRIPT_NAME}-logs"

# Set some defaults
ART_URL=http://localhost
SIZE_MB=1
USER="admin"
PASS="password"
TEST=all
ITERATIONS=2
NUMBER_OF_THREADS=2
SEED=${RANDOM}

######### Functions #########

errorExit () {
    echo -e "\nERROR: $1\n"
    echo "Check logs under ${LOGS_DIR}"
    exit 1
}

usage () {
    cat <<END_USAGE

Usage: ${SCRIPT_NAME} <options>

-l | --url                             : Artifactory URL                            (defaults to ${ART_URL})
-u | --user | --username               : Artifactory user                           (defaults to ${USER})
-p | --pass | --password               : Artifactory password, API key or token     (defaults to ${PASS})
-s | --size                            : Size in MB                                 (defaults to ${SIZE_MB})
-i | --iterations                      : Number of test iterations                  (defaults to ${ITERATIONS})
-t | --test                            : Test type (all|upload|download)            (defaults to ${TEST})
-n | --number-of-threads               : Number of parallel load runs               (defaults to ${NUMBER_OF_THREADS})
-h | --help                            : Show this usage.

Examples:
========
# Test with all defaults - downloads and uploads
$ ${SCRIPT_NAME}

# Test a 10 MB upload 10 times with 5 parallel processes
$ ${SCRIPT_NAME} --url https://server.company.org \\
                 --user admin --password password1x \\
                 --test upload \\
                 --size 10 \\
                 --iterations 10 \\
                 --number-of-threads 5
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
            -s | --size)
                SIZE_MB="$2"
                shift 2
            ;;
            -i | --iterations)
                ITERATIONS="$2"
                shift 2
            ;;
            -t | --test)
                TEST="$2"
                shift 2
            ;;
            -n | --number-of-threads)
                NUMBER_OF_THREADS="$2"
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

    if [[ ! ${TEST} =~ ^(all|download|upload)$ ]]; then
        errorExit "Test type can be 'download' or 'upload' only!"
    fi

    # Add the artifactory context to the ART_URL if missing
    if [[ ! ${ART_URL} =~ \/artifactory\/?$ ]]; then
        ART_URL="${ART_URL%/}"
        ART_URL="${ART_URL}/artifactory"
    fi
}

testArtifactory () {
    echo -n "Check Artifactory readiness... "
    curl --connect-timeout 3 -f -s -k "${ART_URL}/api/v1/system/readiness" -o ${LOGS_DIR}/check-readiness.log || errorExit "Artifactory readiness failed. Check ${LOGS_DIR}/check-readiness.log"
    echo "success"
}

testLoop () {
    local pid_array=()
    local repo_name=load-repo

    echo "##################################################################################################"
    echo "Starting the load loop of ${ITERATIONS} iterations with ${NUMBER_OF_THREADS} parallel processes"
    echo "Running test ${TEST}"
    echo "Using ${SIZE_MB} MB file size as payload"
    echo "##################################################################################################"
    for ((i = 1; i <= ${ITERATIONS}; i++)); do
        echo "--- Iteration ${i}. Starting ${NUMBER_OF_THREADS} parallel threads"
        for ((j = 1; j <= ${NUMBER_OF_THREADS}; j++)); do
            ${ART_BENCH_SCRIPT} --url "${ART_URL}" --user "${USER}" --password "${PASS}" \
                --repo "${repo_name}-${i}-${j}-${SEED}" --test "${TEST}" --size "${SIZE_MB}" --iterations "${ITERATIONS}" \
                --logs ${LOGS_DIR}/load-${i}-${j} --skip-readiness-test >"${LOGS_DIR}/${repo_name}-${j}.log" 2>&1 &
            pid_array[$j]=$!
        done
        echo "Waiting for ${#pid_array[@]} processes (${pid_array[@]})"
        wait
    done
}

checkForErrors () {
    echo "##################################################################################################"
    echo "Checking for errors in the logs..."
    grep -r ERROR ${LOGS_DIR} || echo "No errors found"
    echo "##################################################################################################"
}

main () {
    [[ -f ${ART_BENCH_SCRIPT} ]] || errorExit "Script ${ART_BENCH_SCRIPT} not found"
    processOptions "$@"
    rm -rf "${LOGS_DIR}"
    mkdir -p "${LOGS_DIR}"
    testArtifactory
    testLoop
    checkForErrors
    echo "Done"
}

main "$@"
