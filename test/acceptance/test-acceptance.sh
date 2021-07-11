#!/bin/bash -e

set -o pipefail

# Change to the directory of this script
cd "${0%/*}"

# Configure acceptance and logging directory (inside temporary build)
export ACCEPTANCE_DIR="../../build/acceptance"
export LOG_DIRECTORY="${ACCEPTANCE_DIR}/logs"
mkdir -p "${LOG_DIRECTORY}"

export GODOG_TAGS=${GODOG_TAGS:-"~@wip && ~@skip && ~@manual"}
export GODOG_FORMAT=${GODOG_FORMAT:-"junit:${ACCEPTANCE_DIR}/test-report.xml"}
export GODOG_CONCURRENCY=${GODOG_CONCURRENCY:-10}

dockerize -timeout 300s \
        -wait tcp://server:8080

# Launch acceptance tests
go test --godog.tags="${GODOG_TAGS}" \
        --godog.concurrency="${GODOG_CONCURRENCY}" \
        --godog.format="${GODOG_FORMAT}"
