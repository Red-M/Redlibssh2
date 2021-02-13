import os

from sys import stderr
from subprocess import check_call
from glob import glob
from shutil import copy2
from multiprocessing import cpu_count


def build_ssh2():
    SYSTEM_BUILD_MINGW = bool(os.environ.get('SYSTEM_BUILD_MINGW', 0))
    if bool(os.environ.get('SYSTEM_LIBSSH', False)):
        stderr.write("Using system libssh2..%s" % (os.sep))
        return
    if os.path.exists('/usr/local/opt/openssl'):
        os.environ['OPENSSL_ROOT_DIR'] = '/usr/local/opt/openssl'

    if not os.path.exists('src'):
        os.mkdir('src')

    os.chdir('src')
    if SYSTEM_BUILD_MINGW==1:
        check_call('cmake -DCMAKE_TOOLCHAIN_FILE=../ci/gitlab/windows/windows_toolchain.cmake \
        ../libssh2 -DBUILD_SHARED_LIBS=ON \
        -DENABLE_ZLIB_COMPRESSION=ON -DENABLE_CRYPT_NONE=ON \
        -DENABLE_MAC_NONE=ON -DCRYPTO_BACKEND=OpenSSL',shell=True, env=os.environ)
    else:
        check_call('cmake ../libssh2 -DBUILD_SHARED_LIBS=ON \
        -DENABLE_ZLIB_COMPRESSION=ON -DENABLE_CRYPT_NONE=ON \
        -DENABLE_MAC_NONE=ON -DCRYPTO_BACKEND=OpenSSL',shell=True, env=os.environ)
    check_call('cmake --build . --config Release', shell=True, env=os.environ)
    os.chdir('..')

    if SYSTEM_BUILD_MINGW==1:
        for src in glob('src/src/libssh2.dll'):
            copy2(src, 'ssh2/')
    else:
        for src in glob('src/src/libssh2.so*'):
            copy2(src, 'ssh2/')
