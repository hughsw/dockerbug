#!/bin/bash

# "strict" mode
set -euo pipefail
trap 'rc=$?;set +ex;if [[ $rc -ne 0 ]];then trap - ERR EXIT;echo;echo "*** fail *** : code $rc : $DIR/$SCRIPT $@";echo;exit $rc;fi' ERR EXIT
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$(basename "${BASH_SOURCE[0]}")"


# You can pass the name of a small file as $1 to see non-breaking behavior, e.g. ./go.sh README.md
fileName="${1:-BigBlob.data}"


cat <<EOF

WARNING: This script breaks the host-to-container networking of the Docker engine daemon of Docker
for Mac.  See: https://github.com/docker/for-mac/issues/3487

It will start a MariaDB container (on port 23456), and access the DB in a way that has reliably
broken the Docker engine's host-to-container-networking.  If it succeeds the host will be unable to
make new network connections to any running containers and you will have to restart Docker and the
running containers.

Hit Ctrl-C now to stop this script and thus prevent the attempt to break the Docker engine.
Hit Return to have the script proceed and attempt to break the Docker engine's networking.
EOF

read nonce

# work locally
cd $DIR

# stop the running container, if any
./stop.sh

mkdir -p mysql

# start the DB
export MYSQL_ROOT_PASSWORD=DockerForever
export MYSQL_DATABASE=docker
export MYSQL_USER=docker
export MYSQL_PASSWORD=docker
export MYSQL_PORT=23456

# we run docker in the background (rather than --detach) so we can run go.js in the foreground while still seeing console.log messages from MariaDB
docker run \
       --init \
       --rm \
       -v $(pwd)/mysql:/var/lib/mysql \
       -p ${MYSQL_PORT}:3306 \
       --env MYSQL_ROOT_PASSWORD \
       --env MYSQL_DATABASE \
       --env MYSQL_USER \
       --env MYSQL_PASSWORD \
       --name=dockerbug \
       mariadb:10.3 \
    &


# meanwhile, build libraries
npm install

echo
echo 'Connecting to DB.'
echo 'This may take a while, with repeated messages ending "Connection lost: The server closed the connection."'
echo
echo
sleep 3

# run sequelize and break the Docker engine
node go.js $fileName
