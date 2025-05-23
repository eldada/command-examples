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

    echo "Checking needed variables are set... "
    [[ "${TOOL}" =~ (ab|wrk|hey) ]] || errorExit "TOOL is not set to 'ab', 'wrk' or 'hey'"
    [[ -n "${CONCURRENCY}" ]] || errorExit "CONCURRENCY is not set"
    [[ -n "${TIME_SEC}" ]] || errorExit "TIME_SEC is not set"
    [[ -n "${ARTIFACTORY_URL}" ]] || errorExit "ARTIFACTORY_URL is not set"
    [[ -n "${FILE}" ]] || errorExit "FILE is not set"
    if [[ "${AUTH}" =~ true ]]; then
        echo "AUTH is set to true. Using authenticated access"
        [[ -n "${ARTIFACTORY_USER}" ]] || errorExit "ARTIFACTORY_USER is not set"
        [[ -n "${ARTIFACTORY_PASSWORD}" ]] || errorExit "ARTIFACTORY_PASSWORD is not set"
    else
        echo "AUTH is set to false. Using anonymous access"
    fi

    # Make sure RANDOM_WAIT_TIME_UP_TO is set to an integer and default to 1 if not set
    if [[ -z "${RANDOM_WAIT_TIME_UP_TO}" ]]; then
        RANDOM_WAIT_TIME_UP_TO=1 # This will cause a 0 wait time
    elif [[ ${RANDOM_WAIT_TIME_UP_TO} == "0" ]]; then
        RANDOM_WAIT_TIME_UP_TO=1 # This will cause a 0 wait time
    else
        # Make sure the RANDOM_WAIT_TIME_UP_TO is set to an integer
        if ! [[ "${RANDOM_WAIT_TIME_UP_TO}" =~ ^[0-9]+$ ]]; then
            errorExit "RANDOM_WAIT_TIME_UP_TO is not set to an integer"
        fi
    fi

    echo "success"
}

checkReadiness () {
    echo -e "\n--- Checking Artifactory readiness (${ARTIFACTORY_URL}/artifactory/api/v1/system/readiness)"

    curl -f -s -k "${ARTIFACTORY_URL}/artifactory/api/v1/system/readiness" || errorExit "Artifactory readiness test failed"
}

checkFileExists () {
    if [[ "${ACTION}" =~ "upload" ]]; then
        echo "Upload tests. Skipping file existence check"
        return
    fi

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
        20*|30*)
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

    ab -c ${CONCURRENCY} -t ${TIME_SEC} ${auth} -k "${ARTIFACTORY_URL}/artifactory/${FILE}" || errorExit "Running ab failed"

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
        wrk -d ${TIME_SEC} -c ${CONCURRENCY} -t ${cpu} --latency --timeout 5s -H "Authorization: Basic ${auth_hashed}" "${ARTIFACTORY_URL}/artifactory/${FILE}" || errorExit "Running wrk failed"
    else
        wrk -d ${TIME_SEC} -c ${CONCURRENCY} -t ${cpu} --latency --timeout 5s "${ARTIFACTORY_URL}/artifactory/${FILE}" || errorExit "Running wrk failed"
    fi

    echo -e "\n################################################"
    echo "### Run for ${TIME_SEC} seconds with ${CONCURRENCY} parallel connections done!"
}

runHey () {
    local auth
    local auth_hashed

    if [[ "${AUTH}" =~ true ]]; then
        auth_hashed=$(echo -n ${ARTIFACTORY_USER}:${ARTIFACTORY_PASSWORD} | base64)
        hey_linux_$(arch) -z ${TIME_SEC}s -c ${CONCURRENCY} -m GET -H "Authorization: Basic ${auth_hashed}" "${ARTIFACTORY_URL}/artifactory/${FILE}" || errorExit "Running hey failed"
    else
        hey_linux_$(arch) -z ${TIME_SEC}s -c ${CONCURRENCY} -m GET "${ARTIFACTORY_URL}/artifactory/${FILE}" || errorExit "Running hey failed"
    fi

    echo -e "\n################################################"
    echo "### Run for ${TIME_SEC} seconds with ${CONCURRENCY} parallel connections done!"
}

runUpload () {
    # Download the artifactoryUploadLoad.sh script
    curl -f -s -k "https://raw.githubusercontent.com/eldada/command-examples/refs/heads/master/artifactory/artifactoryUploadLoad.sh" \
        -o artifactoryUploadLoad.sh || errorExit "Downloading artifactoryUploadLoad.sh failed"
    chmod +x artifactoryUploadLoad.sh

    # Run the upload script
    ./artifactoryUploadLoad.sh --url "${ARTIFACTORY_URL}/artifactory" \
                              --user "${ARTIFACTORY_USER}" \
                              --repo "${REPO_PATH}" \
                              --password "${ARTIFACTORY_PASSWORD}" \
                              --number_of_files 600 \
                              --size "${FILE_SIZE_KB}" \
                              --duration "${TIME_SEC}" \
                              --threads "${CONCURRENCY}"

}

runLoad () {
    echo -e "\n--- Running load on Artifactory"
    echo "Run for ${TIME_SEC} seconds with ${CONCURRENCY} parallel connections"

    # Inject a random wait time to avoid all test pods running the test at the same time
    local wait_time=$((RANDOM % RANDOM_WAIT_TIME_UP_TO))
    echo "Waiting ${wait_time} seconds before starting the test"
    sleep ${wait_time}

    if [[ "${ACTION}" =~ "upload" ]]; then
        echo "Upload test"
        runUpload
    else
        echo "Download test"
        while true; do
            echo -e "\n############ Date: $(date)"
            echo "############ Running ${TOOL}"
            if [[ "${ACTION}" =~ "upload" ]]; then
               echo "############ Running uploads!"
            fi

            case "${TOOL}" in
                ab)
                    runAb
                ;;
                wrk)
                    runWrk
                ;;
                hey)
                    runHey
                ;;
                *)
                    errorExit "TOOL ${TOOL} not supported"
                ;;
            esac
            [[ ! "${INFINITE}" =~ true ]] && break
        done
    fi
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
