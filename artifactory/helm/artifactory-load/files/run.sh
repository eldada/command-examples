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

    # Upload is supported with ab only
    if [[ "${ACTION}" =~ "upload" ]]; then
        TOOL=ab
        FILE=${HOSTNAME}
        [[ -n "${REPO_PATH}" ]] || errorExit "REPO_PATH is not set"
    fi

    echo -n "Checking needed variables are set... "
    [[ "${TOOL}" =~ (ab|wrk) ]] || errorExit "TOOL is not set to 'ab' or 'wrk'"
    [[ -n "${CONCURRENCY}" ]] || errorExit "CONCURRENCY is not set"
    [[ -n "${TIME_SEC}" ]] || errorExit "TIME_SEC is not set"
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

    if [[ "${ACTION}" =~ "upload" ]]; then
        echo "Upload tests. Skipping file existence check"
        return
    fi

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
    if [[ "${AUTH}" =~ true ]]; then
        auth="-A ${ARTIFACTORY_USER}:${ARTIFACTORY_PASSWORD}"
    fi

    # If ACTION is upload, create the file to upload
    if [[ "${ACTION}" =~ "upload" ]]; then
        echo "Creating binary file of size ${FILE_SIZE_KB} KB to upload"
        dd if=/dev/random of="/tmp/upload_${FILE_SIZE_KB}" bs=1024 count=${FILE_SIZE_KB} || errorExit "Creating file to upload failed"
        ab -c ${CONCURRENCY} -t ${TIME_SEC} ${auth} -k -u "/tmp/upload_${FILE_SIZE_KB}" "${ARTIFACTORY_URL}/artifactory/${REPO_PATH}/${FILE}" || errorExit "Running ab failed"
    else
        ab -c ${CONCURRENCY} -t ${TIME_SEC} ${auth} -k "${ARTIFACTORY_URL}/artifactory/${FILE}" || errorExit "Running ab failed"
    fi

    echo -e "\n################################################"
    echo "### Run for ${TIME_SEC} seconds with ${CONCURRENCY} parallel connections done!"
}

runWrk () {
    local auth
    local auth_hashed
    local cpu

    # Set the number of threads to the number of CPUs available on the node for highest performance
    cpu=$(nproc)

    if [[ ${cpu} -gt ${CONCURRENCY} ]]; then
        echo "NOTE: Number of CPUs (${cpu}) is higher than the set concurrency (${CONCURRENCY}). Setting cpu to ${CONCURRENCY} to align with wrk limitations"
        cpu=${CONCURRENCY}
    fi

    if [[ "${AUTH}" =~ true ]]; then
        auth_hashed=$(echo -n ${ARTIFACTORY_USER}:${ARTIFACTORY_PASSWORD} | base64)
        wrk -d ${TIME_SEC} -c ${CONCURRENCY} -t ${cpu} --latency -H "Authorization: Basic ${auth_hashed}" "${ARTIFACTORY_URL}/artifactory/${FILE}" || errorExit "Running wrk failed"
    else
        wrk -d ${TIME_SEC} -c ${CONCURRENCY} -t ${cpu} --latency "${ARTIFACTORY_URL}/artifactory/${FILE}" || errorExit "Running wrk failed"
    fi

    echo -e "\n################################################"
    echo "### Run for ${TIME_SEC} seconds with ${CONCURRENCY} parallel connections done!"
}

runLoad () {
    echo -e "\n--- Running load on Artifactory"
    echo "Run for ${TIME_SEC} seconds with ${CONCURRENCY} parallel connections"

    while true; do
        echo -e "\n############ Date: $(date)"
        echo "############ Running ${TOOL}"
        if [[ "${ACTION}" =~ "upload" ]]; then
           echo "############ Running uploads!"
        fi
        if [[ "${TOOL}" =~ ab ]]; then
            runAb
        elif [[ "${TOOL}" =~ wrk ]]; then
            runWrk
        fi
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

    echo "################################################"
}

main "$@"
