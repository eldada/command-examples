#!/bin/bash

# Benchmark Artifactory uploads and downloads
#set -x
SCRIPT_NAME=$0

# Set some defaults
ART_URL=http://localhost/artifactory
REPO="benchmark-tests"
SIZE_MB=1
USER="admin"
PASS="password"
TEST=download
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
-t | --test                            : Test type (upload/download)                (defaults to ${TEST})
-h | --help                            : Show this usage.
--no-headers                           : Don't print headers line.

Examples:
========
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
                ART_URL="$2/artifactory"
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

    if [[ ! ${TEST} =~ ^(download|upload)$ ]]; then
        errorExit "Test type can be 'download' or 'upload' only!"
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
}

deleteTestRepository () {
    echo -n "Deleting test repository ${REPO}... "
    curl -f -s -k -u ${USER}:${PASS} -X DELETE "${ART_URL}/api/repositories/${REPO}"  || errorExit "Deleting repository ${REPO} failed"
}

createFile () {
    local test_file="$1"

    # Create a unique binary, generic file
    echo -n "Creating a $SIZE_MB MB file ${test_file}... "
    dd if=/dev/urandom of="${test_file}" bs=1048576 count="${SIZE_MB}" > ./logs/create-file.log 2>&1 || errorExit "Creating file ${test_file} failed"
    echo "done"
}

createAndUploadTestFile () {
    local test_file="test${SIZE_MB}MB"
    FULL_PATH="${ART_URL}/${REPO}/${test_file}"

    createFile "${test_file}"

    echo "Uploading ${test_file} to ${FULL_PATH}"
    curl -f -k -s -u ${USER}:${PASS} -X PUT -T ./${test_file} "${FULL_PATH}" -o ./logs/upload-out.log || errorExit "Uploading ${test_file} to ${FULL_PATH} failed"

    # Remove file
    echo "Deleting ${test_file}"
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
    echo "Results from ./logs/${TEST}-results.csv"
    echo "======================================== CSV START ================================================="
    cat "./logs/${TEST}-results.csv"
    echo "========================================  CSV END  ================================================="
}

downloadTest () {
    # Create and upload the file to be used for the download tests
    createAndUploadTestFile

    echo "Starting the downloads loop"
    echo "Run #, Test, Download size (bytes), Http response code, Total time (sec), Connect time (sec), Speed (bytes/sec)" > "./logs/${TEST}-results.csv"
    for ((i=1; i <= ${ITERATIONS}; i++)); do
        echo -n "$i, $TEST, " >> "./logs/${TEST}-results.csv"
        curl -L -k -s -f -u ${USER}:${PASS} -X GET "${FULL_PATH}" -o /dev/null --write-out '%{size_download}, %{http_code}, %{time_total}, %{time_connect}, %{speed_download}\n' >> "./logs/${TEST}-results.csv"
        echo -n "."
    done
    echo
    echo "Done"
    deleteTestFile
    printResults
}

uploadTest () {
    local test_file="test${SIZE_MB}MB"
    FULL_PATH="${ART_URL}/${REPO}/${test_file}"

    echo "Starting the uploads loop"
    echo "Run #, Test, Upload size (bytes), Http response code, Total time (sec), Connect time (sec), Speed (bytes/sec)" > "./logs/${TEST}-results.csv"
    for ((i=1; i <= ITERATIONS; i++)); do
        createFile "${test_file}"
        echo -n "$i, $TEST, " >> "./logs/${TEST}-results.csv"
        curl -f -k -s -u ${USER}:${PASS} -X PUT -T ./${test_file} "${FULL_PATH}" -o /dev/null --write-out '%{size_upload}, %{http_code}, %{time_total}, %{time_connect}, %{speed_upload}\n' >> "./logs/${TEST}-results.csv"
    done
    echo "Done"
    deleteTestFile
    printResults
}

main () {
    processOptions "$@"
    rm -rf ./logs
    mkdir -p ./logs
    testArtifactory
    createTestRepository

    case ${TEST} in
        download)
            downloadTest
            ;;
        upload)
            uploadTest
            ;;
    esac

    deleteTestRepository
}

main "$@"
