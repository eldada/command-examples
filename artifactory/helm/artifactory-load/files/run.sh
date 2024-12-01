#!/bin/bash

errorExit () {
    echo "ERROR: $1"
    [[ -n "$2" ]] && cat $2
    echo
    echo "################################################"
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
    echo -e "\n--- Checking Artifactory readiness (${ARTIFACTORY_URL}/artifactory/api/v1/system/readiness)"

    curl -f -s -k "${ARTIFACTORY_URL}/artifactory/api/v1/system/readiness" || errorExit "Artifactory readiness test failed"
}

checkFileExists () {
    echo -e "\n--- Checking File ${FILE} exists and auth is correct (${ARTIFACTORY_URL}/artifactory/${FILE})"
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

    http_code=$(curl -f -s -k -o /dev/null ${head} --write-out "%{http_code}" ${auth} "${ARTIFACTORY_URL}/artifactory/${FILE}")

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
    local start_time
    local end_time
    local total_time
    if [[ "${AUTH}" =~ true ]]; then
        auth="-A ${ARTIFACTORY_USER}:${ARTIFACTORY_PASSWORD}"
    fi
    start_time=$(date +"%s")
    ab -c ${CONCURRENCY} -n ${REQUESTS} ${auth} -k "${ARTIFACTORY_URL}/artifactory/${FILE}" || errorExit "Running ab failed"
    end_time=$(date +"%s")

    total_time=$((end_time - start_time))
    echo -e "\n################################################"
    echo "### Summary"
    echo "### It took ${total_time} seconds to download ${FILE} ${REQUESTS} times with ${CONCURRENCY} concurrent connections"
    echo "################################################"
}

runLoad () {
    echo -e "\n--- Running load on Artifactory"
    echo "Run ${REQUESTS} requests with ${CONCURRENCY} parallel connections"

    while true; do
        echo -e "\n############ Date: $(date)"
        runAb
        [[ ! "${INFINITE}" =~ true ]] && break
    done
}

terminate () {
    echo "Termination detected. Exising..."
    exit 0
}

main () {
    echo -e "\n################################################"

    checkRequirements
    checkReadiness
    checkFileExists
    runLoad

    echo -e "\n################################################"
    echo "### Done"
    echo "################################################"
}

main "$@"
