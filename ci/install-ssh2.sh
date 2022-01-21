#!/bin/bash -xe

if [ -d /opt/local/include/openssl ]; then
    export OPENSSL_ROOT_DIR=/opt/local/include/openssl
fi

mkdir -p src && cd src

if [ "$(uname)" == "Darwin" ];then
    MACOS_DETECTED="asdsdgsdfg"
fi

if [ ! -z $MACOS_DETECTED ]; then
    MACOS_ARGS="-DCMAKE_OSX_ARCHITECTURES=${REDLIB_MACOSX_ARCHITECTURES} -DCMAKE_OSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET}"
    if [ "${REDLIB_MACOSX_ARCHITECTURES}" == "x86_64;arm64" ]; then
        export LDFLAGS="-L/opt/local/lib/"
        export CFLAGS="-I/opt/local/include"
        export CPPFLAGS="-I/opt/local/include -L/opt/local/lib"
        export C_INCLUDE_PATH="/opt/local/include"
        export LIBRARY_PATH="/opt/local/lib"
        export PKG_CONFIG=`which pkg-config`
    fi
fi
if [ ! -z $MACOS_DETECTED ]; then
    cmake ../libssh2 -DBUILD_SHARED_LIBS=ON -DENABLE_ZLIB_COMPRESSION=ON -DENABLE_DEBUG_LOGGING=ON -DCRYPTO_BACKEND=OpenSSL -DCMAKE_INSTALL_PREFIX=../ ${MACOS_ARGS}
else
    cmake ../libssh2 -DBUILD_SHARED_LIBS=ON -DENABLE_ZLIB_COMPRESSION=ON -DENABLE_DEBUG_LOGGING=ON -DCRYPTO_BACKEND=OpenSSL -DCMAKE_INSTALL_PREFIX=../
fi
cmake --build . --config Release --target install
