#!/bin/sh

docker build -t deadbeef -f tools/docker-build/Dockerfile .
mkdir -p docker-build
docker run -v ${PWD}/docker-artifacts:/usr/src/deadbeef/portable deadbeef
