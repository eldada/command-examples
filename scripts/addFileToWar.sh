#!/bin/bash

## Add a file to an existing WAR file (defaults to WEB-INF/lib).
## This script assumes java is installed and the jar executable is used.

SCRIPT_NAME=$0
DEST_PATH=WEB-INF/lib
ADD_FILE=
WAR_FILE=
OUT_FILE=
JAR_EXE=

###### Functions #########

errorExit () {
    echo -e "\nERROR: $1\n"
    exit 1
}

usage () {
    cat << END_USAGE

${SCRIPT_NAME} - Add file to an existing WAR file

Usage: ${SCRIPT_NAME} <options>

-w | --war <WAR file>                : Location of WAR file
-o | --out <destination file>        : The destination WAR file (default is the same as the source WAR file)
-f | --file <file to add>            : The file to add to the WAR
-p | --path <path>                   : Path inside WAR file (default is WEB-INF/lib)
-j | --jar <path>                    : Path to the jar executable
-h | --help                          : Show this usage

Examples:
========
Add file new-lib.jar to my-app.war                   $ ${SCRIPT_NAME} --file new-lib.jar --war /opt/tomcat/webapps/my-app.war

END_USAGE

    exit 1
}

# Process command line options. See usage above for supported options
processOptions () {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -w | --war)
                WAR_FILE="$2"
                shift 2
            ;;
            -o | --out)
                OUT_FILE="$2"
                shift 2
            ;;
            -f | --file)
                ADD_FILE="$2"
                shift 2
            ;;
            -p | --path)
                DEST_PATH="$2"
                shift 2
            ;;
            -j | --jar)
                JAR_EXE="$2"
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

    if [[ -z "$OUT_FILE" ]]; then
        OUT_FILE=$WAR_FILE
    fi

    if [[ -z "$JAVA_HOME" ]] && [[ -z "$JAR_EXE" ]]; then
        errorExit "JAVA_HOME is not set. Set JAVA_HOME or pass jre executable path with --jar <path>"
    fi

    if [[ -z "$JAR_EXE" ]]; then
        JAR_EXE="$JAVA_HOME/bin/jar"
    fi

    [[ -n "$ADD_FILE" ]] || errorExit "Must set file to add (-f | --file)"
}

main () {
    processOptions "$@"
    local workdir=$(mktemp -d)
    cd "$workdir" || errorExit "Change directory to $workdir failed"

    # Make sure file to copy exists
    [[ -f "$ADD_FILE" ]] || errorExit "File $ADD_FILE not found"

    # Extract the war
    echo "Extracting the WAR"
    $JAR_EXE -xf "$WAR_FILE"

    # Copy the extra file
    echo "Adding file $ADD_FILE to $DEST_PATH"
    mkdir -p "$DEST_PATH" || errorExit "Creating $DEST_PATH failed"
    cp -fv "$ADD_FILE" "$DEST_PATH" || errorExit "Copying $ADD_FILE to $DEST_PATH failed"

    # Backing up original WAR
    echo "Backing up $WAR_FILE to /tmp"
    cp -f "$WAR_FILE" /tmp || errorExit "Backing up $WAR_FILE to /tmp failed"

    # Create the new war
    echo "Creating new WAR $OUT_FILE"
    $JAR_EXE -cf "$OUT_FILE" ./* || errorExit "Creating $OUT_FILE failed"

    cd -

    # Cleanup
    rm -rf "$workdir"
}

main "$@"
