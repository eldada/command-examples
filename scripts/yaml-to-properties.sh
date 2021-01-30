#!/usr/bin/env bash

FILE=
KEY=.
LINE=

errorExit () {
    echo; echo "ERROR: $1"; echo
    exit 1
}

usage () {
    cat << END_USAGE

${SCRIPT_NAME} - Convert a section from a YAML formatted file to properties format

Usage: ${SCRIPT_NAME} <options>

-f | --file <name>                : [MANDATORY] Yaml file to process
-k | --key <name>                 : Key to process (default: .)
-h | --help                       : Show this usage

Examples:
========
$ ${SCRIPT_NAME} --file example.yaml --key '.common.key1'

END_USAGE

    exit 1
}

checkYq () {
    [[ $(yq -V) =~ ' 4.' ]] || errorExit "Must have yq v4 installed (https://github.com/mikefarah/yq)"
}

processOptions () {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f | --file)
                FILE="$2"
                shift 2
            ;;
            -k | --key)
                KEY="$2"
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

checkFileExists () {
    [ -n "${FILE}" ] || usage
    [ -f "${FILE}" ] || errorExit "File ${FILE} does not exist"
}

checkKeyExists () {
    if [[ ! ${KEY} =~ ^\. ]]; then KEY=".$KEY"; fi
    [ "$(yq e "${KEY}" "${FILE}")" == "null" ] && errorExit "Key $KEY does not exist"
}

processYaml () {
    local key=$1
    local keys
    local line
    local value

    line=$key

    # Check if there are child keys
    keys=$(yq e "$key | keys" "${FILE}" 2> /dev/null)
    if [ $? -ne 0 ]; then
        # Try to get a value if exists
        value=$(yq e "$key" "${FILE}")
        line="$line=$value"
        echo "$line"
    else
        # Get child keys and do a recursive call to function
        keys=$(echo "$keys" | grep -v "^#" | sed 's,- ,,g' | tr '\n' ' ')

        for k in ${keys}; do
            if [ "$line" == "." ]; then
                processYaml ".$k"
            else
                processYaml "$line.$k"
            fi
        done
    fi
}

main () {
    checkYq
    processOptions "$@"
    checkFileExists
    checkKeyExists
    processYaml "$KEY"
}

######### Main #########

main "$@"
