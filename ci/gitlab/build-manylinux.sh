#!/bin/sh

export DOCKER_TAG=red_m/redlibssh2
rm -rf ./build ./dist ./ssh2/libssh2.* ./libssh2/.git

docker build -t $DOCKER_TAG -f ci/docker/manylinux_2010/Dockerfile .
docker run --rm -v `pwd`:/io $DOCKER_TAG /io/ci/gitlab/build-wheels.sh
ls wheelhouse/
