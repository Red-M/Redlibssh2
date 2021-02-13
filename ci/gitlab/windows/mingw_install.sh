#!/bin/bash

# yum groupinstall -y "MinGW cross-compiler"
yum install -y zstd wget mingw*
mkdir -p ~/mingw
OLD_PATH=$(pwd)
cd ~/mingw
TARGET_PKG=mingw-w64-x86_64-openssl-1.1.1.i-1-any.pkg.tar.zst
wget "https://repo.msys2.org/mingw/x86_64/${TARGET_PKG}"
zstd -d "./${TARGET_PKG}"
tar xvf mingw-w64-x86_64-openssl-*.tar
TARGET_PKG=mingw-w64-x86_64-zlib-1.2.11-9-any.pkg.tar.zst
wget "https://repo.msys2.org/mingw/x86_64/${TARGET_PKG}"
zstd -d "./${TARGET_PKG}"
tar xvf mingw-w64-x86_64-zlib-*.tar
cd "${OLD_PATH}"
