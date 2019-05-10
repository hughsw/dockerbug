# Break the Docker for Mac host-to-container networking

This repo has code that reproducibly breaks the host-to-container networking of Docker for Mac.

See https://github.com/docker/for-mac/issues/3487 for background and discussion.

### Note:
> This code reproducibly breaks the host-to-container networking of Docker for Mac.
It runs a MariaDB container and then accesses that container in a way that breaks Docker's host-to-container networking.
If the code succeeds, the symptom will be that all new network connections from the host to any running container fail with a timeout error.
You will have to restart the Docker engine and the running containers.

## Prerequisites

You will need the following installed on your Mac:
* Docker for Mac 2.0.0.3 (Docker engine 18.09.2)
* or
* Docker for Mac 2.0.0.2 (Docker engine 18.09.1)
* NodeJS version 8.12 or higher
* `npm` version 6.4.1 or higher
* `bash` version 3.2.57 or higher

```bash
bash-3.2$ docker --version
Docker version 18.09.2, build 6247962

bash-3.2$ node --version
v8.12.0

bash-3.2$ npm --version
6.4.1

bash-3.2$ bash --version
GNU bash, version 3.2.57(1)-release (x86_64-apple-darwin17)
Copyright (C) 2007 Free Software Foundation, Inc.
```
![Docker for Mac 2.0.0.3](./DockerForMac-version2.png =350x)
![Docker for Mac 2.0.0.2](./DockerForMac-version.png =350x)

## How to use

Docker for Mac must be running.
No process can be listening on port 23456.

To break the Docker engine, run the shell script `./go.sh` in a terminal.
It will need you to confirm that you want to try to break the Docker engine.
If so, hit Return and wait patiently for up to 60 seconds.

It starts a MariaDB container.
It builds a tiny NodeJS app to talk to the DB container.
It runs the NodeJS app.
Log messages from both a MariaDB container and various shell and NodeJs processes will be interleaved, including failed connection messages.

Be patient.

A successful breakage of the Docker engine will be indicated by logging messages in the terminal that end with something like this:
```
  ...

sequelize: created table
sequelize: created model
AttachmentBlob: Executing (e9bf39e0-d14f-4457-939d-710f57d68d95): START TRANSACTION;
AttachmentBlob: Executing (e9bf39e0-d14f-4457-939d-710f57d68d95): SELECT `documentIdentifier`, `documentBlob`, `createdAt`, `updatedAt` FROM `AttachmentBlobs` AS `AttachmentBlob` WHERE `AttachmentBlob`.\
`documentIdentifier` = 'a1444c70d63e03af60867b1f05ec6cc4da24fd9a2820bf7b6c9814f43edbd4ac' AND `AttachmentBlob`.`documentBlob` = X'494433030000000f3729505249560000200f00007777772e616d617a6f6e2e636f6d003c\
3f786d6c2076657273696f6e3d22312e302220656e636f64696e673d225554462d38223f3e0a3c756974733a5549545320786d6c6e733a7873693d226874 ... for 31107060 characters
2019-01-27 18:50:41 11 [Warning] Aborted connection 11 to db: 'docker' user: 'docker' host: '172.17.0.1' (Got a packet bigger than 'max_allowed_packet' bytes)
AttachmentBlob: Executing (e9bf39e0-d14f-4457-939d-710f57d68d95): COMMIT;
succeeded to find trouble: SequelizeDatabaseError: This socket has been ended by the other party

*** fail *** : code 1 : .../go.sh
```
The smoking-gun part is this:
```
Got a packet bigger than 'max_allowed_packet' bytes
```

If you run `go.sh` again, it will eventually fail with a connection timeout.
This is the symptom that the Docker engine's host-to-container networking is broken.
If you get a connection refusal, that suggests the Docker engine isn't even running (not an expected outcome).
You can also run any other image/container and you should get a timeout error when trying to connect to an exposed port from the host.


`go.sh` will create a couple of Untracked directories:
```
  mysql/
  node_modules/
```

`go.sh` will leave a Docker container running MariaDB.
```bash
docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                    NAMES
a8893615e84d        mariadb:10.3        "docker-entrypoint.s…"   13 minutes ago      Up 13 minutes       0.0.0.0:23456->3306/tcp   dockerbug
```
You can kill it with `./stop.sh`


You will have to restart the Docker engine via the Restart menu item under the Docker icon.

## Details

* [`go.sh [fileName]`](./go.sh) -- kills running containers, starts the MariaDB container, runs `npm install`, runs `go.js fileName`
* [`go.js`](./go.js) -- loads a blob from a file, connects to the DB with Sequelize, creates a table for blobs, sends the blob to the DB, boom!
* [`stop.sh`](./stop.sh) -- stops the running MariaDB container, if any

Read the code.
