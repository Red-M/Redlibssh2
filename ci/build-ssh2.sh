#!/bin/bash -xe

mkdir -p src && cd src
cmake ../libssh2 -DBUILD_SHARED_LIBS=ON -DENABLE_ZLIB_COMPRESSION=ON \
    -DENABLE_DEBUG_LOGGING=ON -DCRYPTO_BACKEND=OpenSSL
cmake --build . --config Release
