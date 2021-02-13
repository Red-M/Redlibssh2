#FROM quay.io/pypa/manylinux2014_x86_64
FROM quay.io/pypa/manylinux2010_x86_64

ENV SYSTEM_LIBSSH2 1
ENV SYSTEM_BUILD_MINGW 1

COPY ./libssh2 /libssh2

COPY ./ci/windows/mingw_install.sh /tmp/mingw_install.sh
COPY ./ci/windows/windows_toolchain.cmake /tmp/windows_toolchain.cmake
RUN bash /tmp/mingw_install.sh
RUN yum -y --disablerepo="epel" install zlib-devel openssl-devel cmake gcc

# Libssh2
RUN mkdir -p build_libssh2 && cd build_libssh2 && \
    cmake -DCMAKE_TOOLCHAIN_FILE=/tmp/windows_toolchain.cmake /libssh2 -DBUILD_SHARED_LIBS=ON -DENABLE_ZLIB_COMPRESSION=ON \
    -DENABLE_CRYPT_NONE=ON -DENABLE_MAC_NONE=ON -DCMAKE_INSTALL_PREFIX=/usr && \
    cmake --build . --config Release --target install

RUN rm -rf build_libssh2
