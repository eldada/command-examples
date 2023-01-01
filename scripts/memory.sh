#!/bin/bash

# A script to spin up a process to hold a given memory block in the air until complete or terminated
# Useful for testing memory usage impact in containers environments such as Kubernetes

SCRIPT_NAME=$0

# Defaults
SIZE_MB=1024
WAIT=300
RESTART=false
GAP=0

errorExit () {
    echo -e "\nERROR: $1\n"
    exit 1
}

usage () {
    cat << END_USAGE

${SCRIPT_NAME} - Create a process to hold RAM memory for a given time

Usage: ${SCRIPT_NAME} <options>

-m | --mb           : Size of memory in MB to hold                              (default $SIZE_MB)
-w | --wait         : Seconds to wait after memory block allocated              (default $WAIT seconds)
-r | --restart      : (true|false) Restart process after wait time passes       (default false)
-g | --gap          : Gap between memory blocks in seconds                      (default 0 - no gap)
-h | --help         : Show this usage

Examples:
========
# Create a 500 MB memory process and wait default time ($WAIT seconds)
$ ${SCRIPT_NAME} --mb 500

# Create a 50 MB memory process and wait 300 seconds
$ ${SCRIPT_NAME} --mb 50 --wait 300

# Create a 100 MB memory process, wait 30 seconds and restart
$ ${SCRIPT_NAME} --mb 100 --wait 300 --restart true

# Create a 100 MB memory process, wait 30 seconds and restart, creating a 30 seconds gap between runs
$ ${SCRIPT_NAME} --mb 100 --wait 300 --restart true --gap 30

END_USAGE

    exit 1
}

# Process command line options. See usage above for supported options
processOptions () {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -m | --mb)
                SIZE_MB="$2"
                shift 2
            ;;
            -w | --wait)
                WAIT="$2"
                shift 2
            ;;
            -r | --restart)
                RESTART="$2"
                shift 2
            ;;
            -g | --gap)
                GAP="$2"
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

# This is the function that actually holds the memory
# Inspired by https://unix.stackexchange.com/a/99390/40526
malloc() {
    echo "Using 'dd' to create a $SIZE_MB MB blob in memory"
    MEMBLOB=$(dd if=/dev/urandom bs=1048576 count=${SIZE_MB} | tr -d '\0')
}

main () {
    processOptions "$@"

    echo "Starting a process to hold $SIZE_MB MB of memory and wait for $WAIT seconds"
    if [[ ${RESTART} =~ true ]]; then
        echo "(Will restart after $WAIT seconds are complete)"
        if [[ ${GAP} -gt 0 ]]; then
            echo "(Will create a gap of $GAP seconds between runs)"
        fi
    fi

    # Create the memory blob
    malloc || errorExit "Running malloc() failed"
    while true; do
        echo "Sleeping for $WAIT seconds"
        sleep "${WAIT}"
        if [[ ${RESTART} =~ false ]]; then
            echo "All done"
            break
        else
            if [[ ${GAP} -gt 0 ]]; then
                echo "- Create a gap of $GAP seconds"
                MEMBLOB=''
                sleep "${GAP}"
                malloc || errorExit "Running malloc() failed"
            fi
        fi
    done
}

main "$@"
