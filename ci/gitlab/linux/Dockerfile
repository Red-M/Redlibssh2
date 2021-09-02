FROM MANYLINUX_DOCKER_CONTAINER

ENV SYSTEM_LIBSSH2 1

COPY ./ci/gitlab/linux /scripts
COPY ./libssh2 /libssh2

RUN /scripts/setup_manylinux.sh

# Libssh2
RUN mkdir -p build_libssh2 && cd build_libssh2 && \
    cmake /libssh2 -DBUILD_SHARED_LIBS=ON -DENABLE_ZLIB_COMPRESSION=ON \
    -DENABLE_CRYPT_NONE=ON -DENABLE_MAC_NONE=ON -DCMAKE_INSTALL_PREFIX=/usr && \
    cmake --build . --config Release --target install

RUN rm -rf build_libssh2
