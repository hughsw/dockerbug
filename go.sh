#!/bin/bash

# "strict" mode
set -euo pipefail
trap 'rc=$?;set +ex;if [[ $rc -ne 0 ]];then trap - ERR EXIT;echo;echo "*** fail *** : code $rc : $DIR/$SCRIPT $@";echo;exit $rc;fi' ERR EXIT
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$(basename "${BASH_SOURCE[0]}")"


# You can pass the name of a small file as $1 to see non-breaking behavior, e.g. ./go.sh README.md
fileName="${1:-BigBlob.data}"


cat <<EOF

WARNING: This script attempts to break the Docker engine daemon of Docker for Mac.  See: https://github.com/docker/for-mac/issues/3487
It will kill all running containers, start a MariaDB container, and use the DB to (attempt to) break the Docker engine's networking.

Hit Ctrl-C now to stop this script and thus prevent the attempt to break the Docker engine.
Hit Return to have the script proceed and attempt to break the Docker engine.
EOF

read nonce

# work locally
cd $DIR

# kill running Docker containers
docker ps | awk '{print $1}' | xargs docker kill || true

# stop the running container, if any
./stop.sh

# start the DB
export MYSQL_ROOT_PASSWORD=DockerForever
export MYSQL_DATABASE=docker
export MYSQL_USER=docker
export MYSQL_PASSWORD=docker

mkdir -p mysql

# we run docker in the background (rather than --detach) so we can run go.js in the foreground while still seeing console.log messages from MariaDB
docker run \
       --init \
       --rm \
       -v $(pwd)/mysql:/var/lib/mysql \
       -p 3306:3306 \
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
echo 'Connecting to DB.  This may take a while, with several "sequelize: failed connect attempt:" messages'
echo

# run sequelize and break the Docker engine
node go.js $fileName
