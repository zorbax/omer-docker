#!/bin/bash

set -eux pipefail

PREFIX="test"
IMAGE=omero-server:$PREFIX

CLEAN=${CLEAN:-y}

cleanup() {
    docker logs $PREFIX-server
    docker rm -f -v $PREFIX-db $PREFIX-server
}

if [ "$CLEAN" = y ]; then
    trap cleanup ERR EXIT
fi

cleanup || true


docker build -t $IMAGE  .
docker run -d --name $PREFIX-db -e POSTGRES_PASSWORD=postgres postgres:14

# Check both CONFIG_environment and *.omero config mounts work
docker run -d --name $PREFIX-server --link $PREFIX-db:db \
    -p 4064 \
    -e CONFIG_omero_db_user=postgres \
    -e CONFIG_omero_db_pass=postgres \
    -e CONFIG_omero_db_name=postgres \
    -e CONFIG_custom_property_fromenv=fromenv \
    -e ROOTPASS=omero-root-password \
    -v $PWD/test-config/config.omero:/opt/omero/server/config/config.omero:ro \
    $IMAGE

# Smoke tests
export OMERO_USER=root
export OMERO_PASS=omero-root-password
export PREFIX

## Login to server

# Must be exported by the caller:
# OMERO_USER OMERO_PASS PREFIX

OMERO=/opt/omero/server/venv3/bin/omero
SERVER="localhost:4064"

# Wait up to 2 mins
docker exec $PREFIX-server $OMERO login -C -s $SERVER -u "$OMERO_USER" -q -w "$OMERO_PASS" --retry 120
echo "OMERO.server connection established"

## Check the Docker OMERO configuration system

docker exec $PREFIX-server $OMERO config get --show-password

[[ $(docker exec $PREFIX-server $OMERO config get custom.property.fromenv) = "fromenv" ]]
[[ $(docker exec $PREFIX-server $OMERO config get custom.property.fromfile) = "fromfile" ]]

# Check whether the certificates plugin worked, AES256-SHA is not enabled by
# default so this command will fail if the certificates plugin failed
docker exec test-server openssl s_client -cipher AES256-SHA -connect localhost:4064

# Wait a minute to ensure other servers are running
sleep 60
## Now that we know the server is up, test Dropbox

# Must be exported by the caller:
# OMERO_USER OMERO_PASS PREFIX

FILENAME=$(date +%Y%m%d-%H%M%S-%N).fake
docker exec $PREFIX-server sh -c \
    "mkdir -p /OMERO/DropBox/root && touch /OMERO/DropBox/root/$FILENAME"

echo -n "Checking for imported DropBox image $FILENAME "
# Retry for 4 mins
i=0
result=
while [ $i -lt 60 ]; do
    sleep 4
    result=$(docker exec $PREFIX-server $OMERO hql -q -s $SERVER -u $OMERO_USER -w $OMERO_PASS "SELECT COUNT (*) FROM Image WHERE name='$FILENAME'" --style plain)
    if [ "$result" = "0,1" ]; then
        echo
        echo "Found image: $result"
        exit 0
    fi
    if [ "$result" != "0,0" ]; then
        echo
        echo "Unexpected query result: $result"
        exit 2
    fi
    echo -n "."
    (( ++i )) || true
done

echo "Failed to find image" && exit 2

## And Processor (slave-1)

# Must be exported by the caller:
# OMERO_USER OMERO_PASS PREFIX

DSNAME=$(date +%Y%m%d-%H%M%S-%N)
SCRIPT=/omero/util_scripts/Dataset_To_Plate.py

dataset_id=$(docker exec $PREFIX-server $OMERO obj -q -s $SERVER -u $OMERO_USER -w $OMERO_PASS new Dataset name=$DSNAME | cut -d: -f2)

docker exec $PREFIX-server sh -c \
    "touch /tmp/$FILENAME && $OMERO import -d $dataset_id /tmp/$FILENAME"

docker exec $PREFIX-server $OMERO script launch $SCRIPT IDs=$dataset_id
echo "Completed with code $?"

result=$(docker exec $PREFIX-server $OMERO hql -q -s $SERVER -u $OMERO_USER -w $OMERO_PASS "SELECT COUNT(w) FROM WellSample w WHERE w.well.plate.name='$DSNAME' AND w.image.name='$FILENAME'" --style plain)
if [ "$result" != "0,1" ]; then
    echo "Script failed: $result"
    exit 2
fi
