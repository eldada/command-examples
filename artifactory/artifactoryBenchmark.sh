#!/bin/bash

# Benchmark Artifactory uploads and downloads
#set -x
SCRIPT_NAME=$0

# Set some defaults
ART_URL=http://localhost
REPO="benchmark-tests"
SIZE_MB=1
USER="admin"
PASS="password"
TEST=all
ITERATIONS=5

######### Functions #########

errorExit () {
    echo -e "\nERROR: $1\n"
    echo "Check logs under ./logs/"
    exit 1
}

usage () {
    cat <<END_USAGE

Usage: ${SCRIPT_NAME} <options>

-l | --url                             : Artifactory URL                            (defaults to ${ART_URL})
-u | --user                            : Artifactory user                           (defaults to ${USER})
-p | --pass | --password               : Artifactory password, API key or token     (defaults to ${PASS})
-r | --repo | --repository             : Repository                                 (defaults to ${REPO})
-s | --size                            : Size in MB                                 (defaults to ${SIZE_MB})
-i | --iterations                      : Number of test iterations                  (defaults to ${ITERATIONS})
-t | --test                            : Test type (all|upload|download)            (defaults to ${TEST})
-h | --help                            : Show this usage.
--no-headers                           : Don't print headers line.

Examples:
========
# Test with all defaults - downloads and uploads
$ ${SCRIPT_NAME}

# Test a 10 MB upload 10 times
$ ${SCRIPT_NAME} --url https://server.company.org \\
                 --user admin --password password1x \\
                 --repo generic-tests \\
                 --test upload \\
                 --size 10 \\
                 --iterations 10
END_USAGE

    exit 1
}

processOptions () {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l | --url)
                ART_URL="$2"
                shift 2
            ;;
            -r | --repo | --repository)
                REPO="$2"
                shift 2
            ;;
            -u | --user)
                USER="$2"
                shift 2
            ;;
            -p | --pass | --password)
                PASS="$2"
                shift 2
            ;;
            -s | --size)
                SIZE_MB="$2"
                shift 2
            ;;
            -i | --iterations)
                ITERATIONS="$2"
                shift 2
            ;;
            -t | --test)
                TEST="$2"
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

    if [[ ! ${TEST} =~ ^(all|download|upload)$ ]]; then
        errorExit "Test type can be 'download' or 'upload' only!"
    fi

    # Add the artifactory context to the ART_URL if missing
    if [[ ! ${ART_URL} =~ \/artifactory\/?$ ]]; then
        ART_URL="${ART_URL}/artifactory"
    fi
}

testArtifactory () {
    echo -n "Check Artifactory readiness... "
    curl -f -s -k "${ART_URL}/api/v1/system/readiness" -o ./logs/check-readiness.log || errorExit "Artifactory readiness failed"
    echo "success"

    echo -n "Check repository ${REPO} does not exist... "
    curl -f -s -k -u ${USER}:${PASS} "${ART_URL}/api/repositories/${REPO}" -o ./logs/check-repository.log && errorExit "Repository ${REPO} already exists. Remove it and try again"
    echo "success"
}

createTestRepository () {
    echo -n "Creating test repository ${REPO}... "
    curl -f -s -k -u ${USER}:${PASS} -X PUT "${ART_URL}/api/repositories/${REPO}" -o ./logs/create-repository.log -H 'Content-Type: application/json' -d "{\"key\":\"${REPO}\",\"rclass\":\"local\",\"packageType\":\"generic\",\"description\":\"Generic local repository for benchmarks\"}" || errorExit "Creating repository ${REPO} failed"
    echo "success"
}

deleteTestRepository () {
    echo -n "Deleting test repository ${REPO}... "
    curl -f -s -k -u ${USER}:${PASS} -X DELETE "${ART_URL}/api/repositories/${REPO}"  || errorExit "Deleting repository ${REPO} failed"
}

createFile () {
    local test_file="$1"

    # Create a unique binary, generic file
    dd if=/dev/urandom of="${test_file}" bs=1048576 count="${SIZE_MB}" > ./logs/create-file.log 2>&1 || errorExit "Creating file ${test_file} failed"
}

createAndUploadTestFile () {
    local test_file="test${SIZE_MB}MB"
    FULL_PATH="${ART_URL}/${REPO}/${test_file}"

    echo -n "Creating a $SIZE_MB MB file ${test_file}... "
    createFile "${test_file}"
    echo "Done"

    echo "Uploading ${test_file} to ${FULL_PATH}"
    curl -f -k -s -u ${USER}:${PASS} -X PUT -T ./${test_file} "${FULL_PATH}" -o ./logs/upload-out.log || errorExit "Uploading ${test_file} to ${FULL_PATH} failed"

    # Remove file
    rm -f "${test_file}" || errorExit "Deleting $test_file failed"
}

deleteTestFile () {
    local test_file="test${SIZE_MB}MB"
    FULL_PATH="${ART_URL}/${REPO}/${test_file}"

    # Delete test file
    echo "Deleting ${FULL_PATH}"
    curl -f -k -s -u ${USER}:${PASS} -X DELETE "${FULL_PATH}" -o ./logs/delete-out.log || errorExit "Deleting ${FULL_PATH} failed"
}

printResults () {
    local test=$1
    echo "Results from ./logs/${test}-results.csv"
    echo "======================================== CSV START ================================================="
    cat "./logs/${test}-results.csv"
    echo "========================================  CSV END  ================================================="
}

downloadTest () {
    local test=download
    echo -e "\n======== DOWNLOADS TEST ========"

    # Create and upload the file to be used for the download tests
    createAndUploadTestFile
    echo "Run #, Test, Download size (bytes), Http response code, Total time (sec), Connect time (sec), Speed (bytes/sec)" > "./logs/${test}-results.csv"
    for ((i=1; i <= ${ITERATIONS}; i++)); do
        echo -n "$i, $test, " >> "./logs/${test}-results.csv"
        curl -L -k -s -f -u ${USER}:${PASS} -X GET "${FULL_PATH}" -o /dev/null --write-out '%{size_download}, %{http_code}, %{time_total}, %{time_connect}, %{speed_download}\n' >> "./logs/${test}-results.csv"
        echo -n "."
    done
    echo
    echo "Done"
    deleteTestFile
    printResults ${test}
}

uploadTest () {
    local test=upload
    local test_file="test${SIZE_MB}MB"
    FULL_PATH="${ART_URL}/${REPO}/${test_file}"

    echo -e "\n========= UPLOADS TEST ========="
    echo "Creating $SIZE_MB MB test files and uploading"
    echo "Run #, Test, Upload size (bytes), Http response code, Total time (sec), Connect time (sec), Speed (bytes/sec)" > "./logs/${test}-results.csv"
    for ((i=1; i <= ITERATIONS; i++)); do
        createFile "${test_file}"
        echo -n "$i, $test, " >> "./logs/${test}-results.csv"
        curl -f -k -s -u ${USER}:${PASS} -X PUT -T ./${test_file} "${FULL_PATH}" -o /dev/null --write-out '%{size_upload}, %{http_code}, %{time_total}, %{time_connect}, %{speed_upload}\n' >> "./logs/${test}-results.csv"
        echo -n "."
    done
    echo
    echo "Done"
    deleteTestFile
    printResults ${test}
}

main () {
    processOptions "$@"
    rm -rf ./logs
    mkdir -p ./logs

    echo -e "\n================================"
    echo "Server      $ART_URL"
    echo "Tests       $TEST"
    echo "User        $USER"
    echo "Repository  $REPO"
    echo "File size   $SIZE_MB MB"
    echo "Iterations  $ITERATIONS"
    echo "================================"
    testArtifactory
    createTestRepository
    echo "================================"

    case ${TEST} in
        download)
            downloadTest
            ;;
        upload)
            uploadTest
            ;;
        all)
            downloadTest
            uploadTest
            ;;
    esac

    deleteTestRepository
    echo
}

main "$@"