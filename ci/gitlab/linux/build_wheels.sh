#!/bin/bash -xe

PYTHON_DIR=${1:-python}
PYTHON_BIN=${2:-python}

OLD_PWD="$(pwd)"
LATEST_PY="$(ls -1d /opt/${PYTHON_DIR}/*/bin | grep -v cpython | tail -n1)/${PYTHON_BIN}"
cd /io
"${LATEST_PY}" /io/setup.py sdist -d /io/wheelhouse --formats=gztar

# Compile wheels
for PYBIN in `ls -1d /opt/${PYTHON_DIR}/*/bin | grep -v cpython`; do
    "${PYBIN}/pip" wheel /io/wheelhouse/*.gz -w /tmp/wheelhouse/
done
cd "${OLD_PWD}"

# Bundle external shared libraries into the wheels
# for whl in /tmp/wheelhouse/*.whl; do
    # auditwheel repair "${whl}" -w /io/wheelhouse/
    # \rm "${whl}"
# done
cp /tmp/wheelhouse/*.whl /io/wheelhouse/

# Install packages and test
for PYBIN in `ls -1d /opt/${PYTHON_DIR}/*/bin | grep -v cpython`; do
    "${PYBIN}/pip" install redlibssh2 --no-index -f /io/wheelhouse
    (cd "${HOME}"; "${PYBIN}/${PYTHON_BIN}" -c 'import ssh2; ssh2.session.Session(); print(ssh2.__version__); print(ssh2.utils.openssl_version_text)')
done
