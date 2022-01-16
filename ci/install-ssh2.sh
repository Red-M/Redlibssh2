#!/bin/bash -xe

if [ -d /usr/local/opt/openssl ]; then
    export OPENSSL_ROOT_DIR=/usr/local/opt/openssl
fi

mkdir -p src && cd src

if [ "$(uname)" == "Darwin" ];then
    MACOS_DETECTED="asdsdgsdfg"
fi

if [ ! -z $MACOS_DETECTED ]; then
    MACOS_ARGS="-DCMAKE_OSX_SYSROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX${MACOSX_DEPLOYMENT_TARGET}.sdk/ -DCMAKE_OSX_ARCHITECTURES=${MACOSX_ARCHITECTURES} -DCMAKE_OSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET}"
fi
if [ ! -z $MACOS_DETECTED ]; then
    cmake ../libssh2 -DBUILD_SHARED_LIBS=ON -DENABLE_ZLIB_COMPRESSION=ON -DENABLE_DEBUG_LOGGING=ON -DCRYPTO_BACKEND=OpenSSL -DCMAKE_INSTALL_PREFIX=../ ${MACOS_ARGS}
else
    cmake ../libssh2 -DBUILD_SHARED_LIBS=ON -DENABLE_ZLIB_COMPRESSION=ON -DENABLE_DEBUG_LOGGING=ON -DCRYPTO_BACKEND=OpenSSL -DCMAKE_INSTALL_PREFIX=../
fi
cmake --build . --config Release --target install
