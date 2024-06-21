#!/bin/bash

set -eux pipefail


export PREFIX=${TRAVIS_BRANCH:-test}
if [ -n "${DOCKER_USERNAME:-}" ] &&  [ -z "${REPO:-}" ]; then
    REPO="${DOCKER_USERNAME}"
else
    REPO="${REPO:-test}"
fi
IMAGE=$REPO/omero-web:$PREFIX
STANDALONE=$REPO/omero-web-standalone:$PREFIX

CLEAN=${CLEAN:-y}

cleanup() {
    docker rm -f -v $PREFIX-web
}

if [ "$CLEAN" = y ]; then
    trap cleanup ERR EXIT
fi

cleanup || true

test_getweb() {
    PREFIX=${PREFIX:-test}

    # Wait up to 2 mins
    i=0
    while ! docker logs "$PREFIX-web" 2>&1 | grep 'Listening at: http://0.0.0.0:4080'
    do
        i=$((i + 1))
        if [ $i -ge 24 ]; then
            echo "$(date) - OMERO.web still not listening, giving up"
            exit 1
        fi
        echo "$(date) - waiting for OMERO.web..."
        sleep 5
    done

    echo "OMERO.web listening"

    # Check the string "test-omero" is present
    curl -sL localhost:4080 | grep test-omero
}

make VERSION="$PREFIX" REPO="$REPO" docker-build

docker run -d --name $PREFIX-web \
    -e CONFIG_omero_web_server__list='[["omero.example.org", 4064, "test-omero"]]' \
    -e CONFIG_omero_web_debug=true \
    -p 4080:4080 \
    $IMAGE

test_getweb

# Standalone image
cleanup
docker run -d --name $PREFIX-web \
    -e CONFIG_omero_web_server__list='[["omero.example.org", 4064, "test-omero"]]' \
    -e CONFIG_omero_web_debug=true \
    -p 4080:4080 \
    $STANDALONE

test_getweb

if [ -n "${DOCKER_USERNAME:-}" ]; then
    echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
    make  VERSION="$PREFIX" REPO="$REPO" docker-push
else
    echo Docker push disabled
fi
