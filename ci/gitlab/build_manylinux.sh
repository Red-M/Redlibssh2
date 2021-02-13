#!/bin/sh

export DOCKER_TAG=red_m/redlibssh2
rm -rf ./build ./dist ./ssh2/libssh2.* ./libssh2/.git

docker build -t $DOCKER_TAG -f ci/gitlab/Dockerfile .
docker run --rm -v `pwd`:/io $DOCKER_TAG /io/ci/gitlab/build_linux_wheels.sh
ls wheelhouse/
