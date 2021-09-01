#!/bin/sh

export DOCKER_TAG=red_m/redlibssh2
rm -rf ./build ./dist ./ssh2/libssh2.* ./libssh2/.git

docker build -t $DOCKER_TAG -f ci/gitlab/linux/Dockerfile_manylinux .
docker run --rm -v `pwd`:/io $DOCKER_TAG /io/ci/gitlab/linux/build_wheels.sh
ls wheelhouse/
