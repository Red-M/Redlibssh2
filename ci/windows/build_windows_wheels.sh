#!/bin/bash -xe

yum groupinstall -y "MinGW cross-compiler"
yum install -y zstd wget
mkdir -p ~/mingw
OLD_PATH=$(pwd)
cd ~/mingw
TARGET_PKG=mingw-w64-x86_64-openssl-1.1.1.i-1-any.pkg.tar.zst
wget "https://repo.msys2.org/mingw/x86_64/${TARGET_PKG}"
zstd -d "./${TARGET_PKG}"
cd "${OLD_PATH}"
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
