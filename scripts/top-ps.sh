#!/bin/bash

## Extract resources usage by processes from the ps command along with totals reported

SCRIPT_NAME=$0
RATE=5
PID=

######### Functions #########

errorExit () {
    echo -e "\nERROR: $1\n"
    exit 1
}

usage () {
    cat << END_USAGE

${SCRIPT_NAME} - Show resources usage per processes ("simple" top)

Usage: ${SCRIPT_NAME} <options>

-p | --pid <process id>                : Show data for provided process if only.    Default: all processes
-o | --once                            : Output once.                               Default: infinite loop
-r | --rate                            : Refresh rate (seconds).                    Default: 5
-h | --help                            : Show this usage.
--no-headers                           : Don't print headers line.

Examples:
========
Show all:                              $ ${SCRIPT_NAME}
Show all (refresh rate 10 seconds):    $ ${SCRIPT_NAME} --rate 10
Show once:                             $ ${SCRIPT_NAME} --once
Show for single pid:                   $ ${SCRIPT_NAME} --pid 1234

END_USAGE

    exit 1
}

# Process command line options. See usage above for supported options
processOptions () {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p | --pid)
                PID="$2"
                shift 2
            ;;
            -o | --once)
                ONCE=true
                shift 1
            ;;
            -r | --rate)
                RATE=$2
                [ "${RATE}" -eq "${RATE}" ] 2> /dev/null || errorExit "Refresh rate must be an integer"
                [ "${RATE}" -gt 0 ] 2> /dev/null || errorExit "Refresh rate must be an integer higher than 0"
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

# The main loop
main () {
    # Check we have the ps executable
    ps > /dev/null 2>&1 || errorExit "Missing the 'ps' command"

    processOptions "$@"
    local extra_args=
    local input=

    if [ -n "$PID" ]; then
        extra_args="-p $PID"
    fi

    while true; do
        [ -z "${ONCE}" ] && printf "\033c" # Don't clear screen if it's only once

        echo "----------------------------------------------------"
        ps -eo pid,ppid,rss:10,%mem,%cpu,cmd $extra_args | grep -v 'ps -eo'
        echo "----------------------------------------------------"

        echo -n "* CPU Cores: "; nproc
        echo "* Memory: "; free -th

        [ -n "${ONCE}" ] && break # Exit if asked for only once
        read -r -s -n 1 -t "${RATE}" input
        if [[ "${input}" = "q" ]] || [[ "${input}" = "Q" ]]; then
            echo
            break
        fi
        sleep "${RATE}"
    done
}

main "$@"
