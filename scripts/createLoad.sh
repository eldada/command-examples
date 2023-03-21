#!/bin/bash

# A simple script to create disk IO and CPU load in the current environment.
# This script just creates and deletes files in a temp directory which strains the CPU and disk IO.
# WARNING: Running this script with many threads can bring a system to a halt or even crash it. USE WITH CARE!

SCRIPT_NAME=$0
THREADS=1
# For initial protection from overloading. Change with care
THREADS_LIMIT=10
TESTS_LOAD_DIR=/tmp/${SCRIPT_NAME}
PID_ARRAY=()

######### Functions #########

errorExit () {
    echo -e "\nERROR: $1\n"
    exit 1
}

killAll (){
    echo -e "\nKilling all PIDs (${PID_ARRAY[@]})"
    kill ${PID_ARRAY[@]} > /dev/null 2>&1 || errorExit "Killing PIDs failed (${PID_ARRAY[@]})"
}

cleanup (){
    killAll
    echo "Deleting ${TESTS_LOAD_DIR}"
    rm -rfv "${TESTS_LOAD_DIR}" && echo "SUCCESS"
    echo "Terminating"
    exit 0
}

usage () {
    cat <<END_USAGE

Usage: ${SCRIPT_NAME} <options>

-t | --treads           : Number of load threads to create          (defaults to ${THREADS})
-l | --limit            : Limit number of threads allowed           (defaults to ${THREADS_LIMIT})
-h | --help             : Show this usage.

Examples:
========
# Run with the default ${THREADS} threads
$ ./${SCRIPT_NAME}

# Run load with 5 threads
$ ${SCRIPT_NAME} --threads 5

# Run load with 15 threads (override threads limit)
$ ${SCRIPT_NAME} --threads 15 --limit 15
END_USAGE

    exit 1
}

processOptions () {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t | --threads)
                THREADS="$2"
                shift 2
            ;;
            -l | --limit)
                THREADS_LIMIT="$2"
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

    # Validate the input is a valid integer between the limits
    [[ "${THREADS}" -le "${THREADS_LIMIT}" ]] || errorExit "Threads must be a valid integer between 1 and ${THREADS_LIMIT}"
    [[ "${THREADS}" -le "${THREADS_LIMIT}" ]] && [[ "${THREADS}" -gt 0 ]] || errorExit "Threads must be a valid integer between 1 and ${THREADS_LIMIT}"
}


main () {
    processOptions "$@"
    echo "Creating load with ${THREADS} threads"
    mkdir -p "${TESTS_LOAD_DIR}" || errorExit "Creating ${TESTS_LOAD_DIR} failed"

    for (( i=0; i<THREADS; i++ )); do
        while true; do
            echo 1234567890 >> "${TESTS_LOAD_DIR}/${i}"
            rm -f "${TESTS_LOAD_DIR}/${i}"
        done > /dev/null 2>&1 &
        PID_ARRAY[i]=$!
    done
    echo "Load threads running processes (${PID_ARRAY[@]})"
    wait
}

trap cleanup SIGINT SIGTERM ERR

main "$@"
