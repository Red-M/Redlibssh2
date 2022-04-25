#!/bin/sh

DOCKER_CONTAINER=${1:-quay.io/pypa/manylinux2010_x86_64}
PYTHON_DIR=${2:-python}
PYTHON_BIN=${3:-python}

export DOCKER_TAG=red_m/redlibssh2
rm -rf ./build ./dist ./ssh2/libssh2.* ./libssh2/.git

\cp ./ci/gitlab/linux/Dockerfile /tmp/
sed -i 's#MANYLINUX_DOCKER_CONTAINER#'"${DOCKER_CONTAINER}"'#g' /tmp/Dockerfile

docker build -t $DOCKER_TAG -f /tmp/Dockerfile .
docker run --rm -v `pwd`:/io $DOCKER_TAG /io/ci/gitlab/linux/build_wheels.sh "${PYTHON_DIR}" "${PYTHON_BIN}" "/io/ci/monkeypatch_auditwheel.py"
ls wheelhouse/
