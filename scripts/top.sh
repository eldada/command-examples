#!/bin/bash

PROC_DATA=.proc-data
SCRIPT_NAME=$0
HEADERS=true
RATE=2

hertz=$(getconf CLK_TCK)
command=
cpu_usage=
memory_mb=

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
-o | --once                            : Output once.                               Default: infinit loop
-r | --rate                            : Refresh rate (seconds).                    Default: 2
-h | --help                            : Show this usage.
--no-headers                           : Don't print headers line.

Examples:
========
Show all:                              $ ${SCRIPT_NAME}
Show all (refresh rate 5 seconds):     $ ${SCRIPT_NAME} --rate 5
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
                SINGLE_PID=true
                shift 2
            ;;
            -o | --once)
                ONCE=true
                shift 1
            ;;
            -r | --rate)
                RATE=$2
                shift 2
            ;;
            --no-headers)
                HEADERS=false
                shift 1
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

getCommand () {
     command=$(cat /proc/${PID}/comm)
}

getCpu () {
    uptime_array=($(cat /proc/uptime))
    uptime=${uptime_array[0]}

    stat_array=($(cat /proc/${PID}/stat))

    utime=${stat_array[13]}
    stime=${stat_array[14]}
    cutime=${stat_array[15]}
    cstime=${stat_array[16]}
    start_time=${stat_array[21]}

    total_time=$(( $utime + $stime ))
    total_time=$(( $total_time + $cstime + $cutime ))

    seconds=$(awk 'BEGIN {print ( '${uptime}' - ('${start_time}' / '${hertz}') )}')
    cpu_usage=$(awk 'BEGIN {print ( 100 * (('$total_time' / '$hertz') / '$seconds') )}')
}

getMemory () {
    memory_rss=$(grep 'VmRSS:' /proc/${PID}/status | awk '{print $2}')
    memory_mb=$(awk 'BEGIN {print ( '$memory_rss' / 1024 )}')
}

# The main loop
main () {
    processOptions $*

    while true; do
        echo '' > ${PROC_DATA} || errorExit "Failed writing ${PROC_DATA}"

        # If user asks for single pid
        if [ -n "${PID}" ] && [ "${SINGLE_PID}" == true ] ; then
            pid_array="${PID}"
        else
            # shellcheck disable=SC2010
            pid_array=$(ls /proc | grep -E '^[0-9]+$')
        fi
        for p in $pid_array; do
            if [ -f /proc/$p/stat ]; then
                PID=$p
                getCommand
                getCpu
                getMemory

                printf "%-7d %-20s %-10.2f %-10.2f\n" $p $command $cpu_usage $memory_mb >> ${PROC_DATA}
            fi
        done

        clear
        if [ "${HEADERS}" == true ]; then
            printf "%-7s %-20s %-10s %-10s\n" "PID" "COMMAND" "%CPU" "MEM (MB)"
        fi
        sort -n -k1 ${PROC_DATA} | head -50

        [ -n "${ONCE}" ] && break
        sleep ${RATE}
    done
}

main $*
