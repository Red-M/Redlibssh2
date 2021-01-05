#!/bin/bash -xe

OLD_PWD="$(pwd)"
LATEST_PY="$(ls -1d /opt/python/*/bin | grep -v cpython | tail -n1)/python"
cd /io
"${LATEST_PY}" /io/setup.py sdist -d /io/wheelhouse --formats=gztar

# Compile wheels
for PYBIN in `ls -1d /opt/python/*/bin | grep -v cpython`; do
    "${PYBIN}/pip" wheel /io/wheelhouse/*.gz -w /io/wheelhouse/
done
cd "${OLD_PWD}"

# Bundle external shared libraries into the wheels
for whl in /io/wheelhouse/*.whl; do
    auditwheel repair "${whl}" -w /io/wheelhouse/
    \rm "${whl}"
done

# Install packages and test
for PYBIN in `ls -1d /opt/python/*/bin | grep -v cpython`; do
    "${PYBIN}/pip" install redlibssh2 --no-index -f /io/wheelhouse
    (cd "${HOME}"; "${PYBIN}/python" -c 'import ssh2; ssh2.session.Session(); print(ssh2.__version__)')
done
