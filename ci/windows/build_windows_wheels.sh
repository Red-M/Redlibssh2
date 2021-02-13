#!/bin/bash -xe


export SYSTEM_BUILD_MINGW=1

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
