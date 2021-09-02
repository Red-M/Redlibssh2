#!/bin/sh

DOCKER_CONTAINER=${1:-quay.io/pypa/manylinux2010_x86_64}

export DOCKER_TAG=red_m/redlibssh2
rm -rf ./build ./dist ./ssh2/libssh2.* ./libssh2/.git

cp ./ci/gitlab/linux/Dockerfile_manylinux /tmp/
sed -i 's#MANYLINUX_DOCKER_CONTAINER#'"${DOCKER_CONTAINER}"'#g' /tmp/Dockerfile_manylinux

docker build -t $DOCKER_TAG -f /tmp/Dockerfile_manylinux .
docker run --rm -v `pwd`:/io $DOCKER_TAG /io/ci/gitlab/linux/build_wheels.sh
ls wheelhouse/
