#!/bin/bash

PROC_DIR=/proc
PROC_DATA=/tmp/.proc-data
SCRIPT_NAME=$0
HEADERS=true
RATE=5

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
-o | --once                            : Output once.                               Default: infinite loop
-r | --rate                            : Refresh rate (seconds).                    Default: 5
-d | --dir | --directory <directory>   : Use custom /proc directory                 Default: /proc
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
                SINGLE_PID=true
                shift 2
            ;;
            -o | --once)
                ONCE=true
                shift 1
            ;;
            -r | --rate)
                RATE=$2
                [ ${RATE} -eq ${RATE} ] 2> /dev/null || errorExit "Refresh rate must be an integer"
                [ ${RATE} -gt 0 ] 2> /dev/null || errorExit "Refresh rate must be an integer higher than 0"
                shift 2
            ;;
            -d | --dir | --directory)
                PROC_DIR="$2"
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
     command=$(cat ${PROC_DIR}/${PID}/comm)
}

getCpu () {
    uptime_array=($(cat ${PROC_DIR}/uptime))
    uptime=${uptime_array[0]}

    stat_array=($(cat ${PROC_DIR}/${PID}/stat))

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
    memory_rss=$(grep 'VmRSS:' ${PROC_DIR}/${PID}/status | awk '{print $2}')
    memory_mb=$(awk 'BEGIN {print ( '$memory_rss' / 1024 )}')
}

# The main loop
main () {
    processOptions "$@"
    local total_cpu=0
    local total_memory=0

    while true; do
        echo '' > ${PROC_DATA} || errorExit "Failed writing ${PROC_DATA}"

        # If user asks for single pid
        if [ -n "${PID}" ] && [ "${SINGLE_PID}" == true ] ; then
            pid_array="${PID}"
        else
            # shellcheck disable=SC2010
            pid_array=$(ls ${PROC_DIR} | grep -E '^[0-9]+$')
        fi

        total_cpu=0
        total_memory=0

        for p in $pid_array; do
            if [ -f ${PROC_DIR}/$p/stat ]; then
                PID=$p
                getCommand
                getCpu
                getMemory

                printf "%-7d %-20s %-10.2f %-10.2f\n" $p $command $cpu_usage $memory_mb >> ${PROC_DATA}
                total_cpu=$(awk 'BEGIN {print ( '$total_cpu' + '$cpu_usage')}')
                total_memory=$(awk 'BEGIN {print ( '$total_memory' + '$memory_mb')}')
            fi
        done

        clear
        if [ "${HEADERS}" == true ]; then
            printf "%-7s %-20s %-10s %-10s\n" "PID" "COMMAND" "%CPU" "MEM (MB)"
            echo -n "-----------------------------------------------"
        fi
        sort -n -k1 ${PROC_DATA} | head -50
        echo "-----------------------------------------------"
        printf "%-7s %-20s %-10.2f %-10.2f\n" "-" "-" $total_cpu $total_memory

        [ -n "${ONCE}" ] && break
        read -s -n 1 -t ${RATE} input
        if [[ $input = "q" ]] || [[ $input = "Q" ]]; then
            echo
            break
        fi
    done
}

main "$@"
