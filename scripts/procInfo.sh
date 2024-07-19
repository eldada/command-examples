#!/bin/bash

## Get process info for a PID or process name from /proc
## This script assumes the use of the /proc file system for representation of Linux processes
SCRIPT_NAME=$0
PROC_DIR=/proc
PS=false
PID=
STRING=
HEADERS=false

######### Functions #########

errorExit () {
    echo -e "\nERROR: $1\n"
    exit 1
}

usage () {
    cat << END_USAGE

${SCRIPT_NAME} - Search and get process info based on PID or search string

Usage: ${SCRIPT_NAME} <options>

-l | --list                            : Get list of running processes
-p | --pid <process id>                : Search process using PID
-s | --string <search string>          : Search process using search string
-d | --dir | --directory <directory>   : Use custom /proc directory                    Default: /proc
-h | --help                            : Show this usage.

Examples:
========
Get list of running processes                                 $ ${SCRIPT_NAME} --list
Get process info for process with PID 5151                    $ ${SCRIPT_NAME} --pid 5151
Get process info for process using search string "fluent"     $ ${SCRIPT_NAME} --string fluent
Get process info for PID 171717 in directory /tmp/proc        $ ${SCRIPT_NAME} --pid 171717 --directory /tmp/proc

END_USAGE

    exit 1
}

# Process command line options. See usage above for supported options
processOptions () {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l | --list)
                PS=true
                shift 1
            ;;
            -p | --pid)
                PID="$2"
                shift 2
            ;;
            -s | --string)
                STRING="$2"
                shift 2
            ;;
            -d | --dir | --directory)
                PROC_DIR="$2"
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

    if [[ "$PS" =~ false ]] && [[ -z "$PID" ]] && [[ -z "$STRING" ]]; then
        usage
        errorExit "Must specify PID or search string"
    fi

    [ -d "$PROC_DIR" ] || errorExit "PROC_DIR must be a directory"
}

getProcessInfo () {
    local dir=$1

    echo -e "\nCommand line:\n----------------------"
    cat "$PROC_DIR/$dir/cmdline" | tr '\0' ' '

    echo -e "\n\nEnvironment variables:\n----------------------"
    cat "$PROC_DIR/$dir/environ" | tr '\0' '\n'
}

main () {
    processOptions "$@"

    # Just get list of running processes
    if [[ "$PS" == true ]]; then
        echo -e "List of running processes\n----------------------"
        for a in $(ls -d ${PROC_DIR}/*/); do
            if [[ -f $a/exe ]]; then
                ls -l ${a}exe
            fi
        done
        return
    fi

    cd "$PROC_DIR" || errorExit "Unable to change directory to $PROC_DIR"
    # Get by PID or string
    if [ -n "$PID" ]; then
        [ -d "$PROC_DIR/$PID" ] || errorExit "$PROC_DIR/$PID must be a directory"
        echo -e "Info for PID $PID\n----------------------"
        getProcessInfo "$PID"
    else
        # Roll over all files in PROC_DIR
        for a in *; do
            if [ -d "$a" ] && [ "$a" -eq "$a" ] 2>/dev/null; then
                # echo "Directory $a"
                cd "$PROC_DIR/$a" || errorExit "Failed cd to $PROC_DIR/$a"
                if ls -l exe 2> /dev/null | grep "$STRING" > /dev/null 2>&1 ; then
                    echo -e "\nFound '$STRING' in $PROC_DIR/$a\n----------------------"
                    getProcessInfo "$a"
                fi
                cd "$PROC_DIR" || errorExit "Failed cd to $PROC_DIR"
            fi
        done
        echo
    fi
}

main "$@"
