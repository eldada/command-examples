#!/bin/bash

errorExit () {
    echo "ERROR: $1"
    [[ -n "$2" ]] && cat $2
    echo
    exit 1
}

checkRequirements () {
    echo -e "\n--- Checking required variables"

    echo -n "Checking needed variables are set... "
    [[ -n "${ARTIFACTORY_URL}" ]] || errorExit "ARTIFACTORY_URL is not set"
    [[ -n "${FILE}" ]] || errorExit "FILE is not set"
    if [[ "${AUTH}" =~ true ]]; then
        [[ -n "${ARTIFACTORY_USER}" ]] || errorExit "ARTIFACTORY_USER is not set"
        [[ -n "${ARTIFACTORY_PASSWORD}" ]] || errorExit "ARTIFACTORY_PASSWORD is not set"
    fi
    echo "success"
}

checkReadiness () {
    echo -e "\n--- Checking Artifactory readiness"

    curl -f -s "${ARTIFACTORY_URL}/artifactory/api/v1/system/readiness" || errorExit "Artifactory readiness test failed"
}

checkFileExists () {
    echo -e "\n--- Checking File ${FILE} exists and auth is correct"
    local http_code
    local auth
    local head="--head"
    
    if [[ "${AUTH}" =~ true ]]; then
        auth="-u ${ARTIFACTORY_USER}:${ARTIFACTORY_PASSWORD}"
    fi

    # Handle cases where liveness or readiness are sent, don't use HEAD (--head)
    if [[ "${FILE}" =~ api.*(liveness|readiness) ]]; then
        head=
    fi

    http_code=$(curl -f -s -o /dev/null ${head} --write-out "%{http_code}" ${auth} "${ARTIFACTORY_URL}/artifactory/${FILE}")

    case "${http_code}" in
        20*)
            echo "File ${FILE} exists and auth is good (http code ${http_code})"
        ;;
        401)
            errorExit "Got \"401 Unauthorized\" on ${FILE}"
        ;;
        404)
            errorExit "Got \"404 Not Found\" on ${FILE}"
        ;;
        *)
            errorExit "Got http code ${http_code} on ${FILE}. Exiting"
        ;;
    esac
}

runAb () {
    local auth
    if [[ "${AUTH}" =~ true ]]; then
        auth="-A ${ARTIFACTORY_USER}:${ARTIFACTORY_PASSWORD}"
    fi
    ab -c ${CONCURRENCY} -n ${REQUESTS} ${auth} -d -q -S "${ARTIFACTORY_URL}/artifactory/${FILE}" || errorExit "Running ab failed"
}

runLoad () {
    echo -e "\n--- Running load on Artifactory in an infinite loop"
    echo "Run ${REQUESTS} requests with ${CONCURRENCY} parallel connections"

    if [[ "${INFINITE}" =~ true ]]; then
        echo "Running an infinite loop"
        while true; do
            echo "############ Date: $(date)"
            runAb
        done
    else
        echo "Running once"
        runAb
    fi
}

terminate () {
    echo "Termination detected. Exising..."
    exit 0
}

main () {
    echo -e "\n-------------------------------------"

    checkRequirements
    checkReadiness
    checkFileExists
    runLoad

    echo "-------------------------------------"
    echo "Done. Sleeping for a day..."
    echo "-------------------------------------"
    sleep 1d
}

main "$@"
