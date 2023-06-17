#!/bin/bash -xe
export Build_MACOSX_DEPLOYMENT_TARGET_DIR=''
if [[ ! -z "${MACOSX_DEPLOYMENT_TARGET}" ]]; then
    export Build_MACOSX_DEPLOYMENT_TARGET_DIR="${MACOSX_DEPLOYMENT_TARGET}/"
fi
export Build_ROOT_DIR="${HOME}/${Build_MACOSX_DEPLOYMENT_TARGET_DIR}"
export BUILD_PYENV_VERSIONS=("${PYENV:-ALL}")
export PYENV_ROOT="${Build_ROOT_DIR}.pyenv"
export VENV_ROOT="${Build_ROOT_DIR}venv"
export PATH="${PYENV_ROOT}/bin:${PATH}"
ALL_PYENV_VERSION_DEFAULT=("ALL")
# ALL_BUILD_PYENV_VERSIONS=("3.10.1" "3.9.7" "3.8.12" "3.7.12" "3.6.14" "3.5.10" "pypy3.8-7.3.7" "pypy3.7-7.3.7" "pypy3.6-7.3.3")
ALL_BUILD_PYENV_VERSIONS=("3.10.1" "3.9.7" "3.8.12" "3.7.12" "3.6.14" "3.5.10")

export PATH="$(echo ~/.pyenv/bin/pyenv):$PATH"
export Build_PYTHON_CONFIGURE_OPTS="--enable-optimizations --enable-framework --enable-ipv6 --enable-loadable-sqlite-extensions --with-computed-gotos --with-ensurepip=no --with-system-expat --with-system-ffi"
export Build_UNIVERSAL2_PYTHON_CONFIGURE_OPTS="${Build_PYTHON_CONFIGURE_OPTS} --enable-universalsdk=/ --with-universal-archs=universal2"

if [ ${BUILD_PYENV_VERSIONS[@]} = ${ALL_PYENV_VERSION_DEFAULT[@]} ]; then
    BUILD_PYENV_VERSIONS=(${ALL_BUILD_PYENV_VERSIONS[@]})
fi


set +x
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
set -x
if [[ ! -d "${VENV_ROOT}" ]]; then
    mkdir "${VENV_ROOT}"
fi

for PYENV in ${BUILD_PYENV_VERSIONS[@]}; do
    export PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1
    export SETUPTOOLS_USE_DISTUTILS=stdlib
    export LDFLAGS="-L/opt/local/lib/"
    export CFLAGS="-I/opt/local/include"
    export CPPFLAGS="-I/opt/local/include -L/opt/local/lib"
    export C_INCLUDE_PATH="/opt/local/include"
    export LIBRARY_PATH="/opt/local/lib"
    export PKG_CONFIG=`which pkg-config`
    export Build_MACOSX_REQUIRED_ARCHITECTURES="x86_64"

    if [[ $PYENV == 3.5* ]]; then
        if [[ "${MACOSX_DEPLOYMENT_TARGET}" == "11.3" ]]; then
            exit 0
        fi
        PY_PATCH=( 'https://github.com/macports/macports-ports/raw/master/lang/python35/files/patch-setup.py.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python35/files/patch-Lib-cgi.py.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python35/files/patch-configure.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python35/files/patch-Lib-ctypes-macholib-dyld.py.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python35/files/patch-libedit.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python35/files/omit-local-site-packages.patch'
        'https://github.com/macports/macports-ports/raw/master/lang/python35/files/patch-configure-xcode4bug.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python35/files/Modules_posixmodule.c.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python35/files/uuid-64bit.patch'
        'https://github.com/macports/macports-ports/raw/master/lang/python35/files/patch-_osx_support.py.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python35/files/darwin20.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python35/files/implicit.patch'
        'https://github.com/macports/macports-ports/raw/master/lang/python35/files/sysconfig.py.diff' )
    elif [[ $PYENV == 3.6* ]]; then
        if [[ "${MACOSX_DEPLOYMENT_TARGET}" == "11.3" ]]; then
            exit 0
        fi
        PY_PATCH=( 'https://github.com/macports/macports-ports/raw/master/lang/python36/files/patch-setup.py.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python36/files/patch-Lib-cgi.py.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python36/files/patch-configure.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python36/files/patch-Lib-ctypes-macholib-dyld.py.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python36/files/patch-libedit.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python36/files/omit-local-site-packages.patch'
        'https://github.com/macports/macports-ports/raw/master/lang/python36/files/patch-configure-xcode4bug.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python36/files/patch-_osx_support.py.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python36/files/darwin20.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python36/files/implicit.patch'
        'https://github.com/macports/macports-ports/raw/master/lang/python36/files/sysconfig.py.diff' )
    elif [[ $PYENV == 3.7* ]]; then
        PY_PATCH=( 'https://github.com/macports/macports-ports/raw/master/lang/python37/files/patch-setup.py.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python37/files/patch-Lib-cgi.py.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python37/files/patch-configure.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python37/files/patch-Lib-ctypes-macholib-dyld.py.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python37/files/patch-libedit.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python37/files/patch-configure-xcode4bug.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python37/files/implicit.patch'
        'https://github.com/macports/macports-ports/raw/master/lang/python37/files/sysconfig.py.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python37/files/distutils_spawn.py.patch'
        'https://github.com/macports/macports-ports/raw/master/lang/python37/files/macos11.patch' )
    elif [[ $PYENV == 3.8* ]]; then
        PY_PATCH=( 'https://github.com/macports/macports-ports/raw/master/lang/python38/files/patch-setup.py.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python38/files/patch-Lib-cgi.py.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python38/files/patch-configure.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python38/files/patch-Lib-ctypes-macholib-dyld.py.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python38/files/patch-libedit.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python38/files/patch-configure-xcode4bug.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python38/files/sysconfig.py.diff'
        'https://gist.github.com/Red-M/ea79dd7d0762bf799ccbaff4df53cada/raw/0ce0529bb51a22291e732d3d32c67fd697b1e97e/distutils_spawn.py.patch' )
    elif [[ $PYENV == 3.9* ]]; then
        PY_PATCH=( #'https://github.com/macports/macports-ports/raw/master/lang/python39/files/patch-setup.py.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python39/files/patch-Lib-cgi.py.diff'
        # 'https://github.com/macports/macports-ports/raw/master/lang/python39/files/patch-configure.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python39/files/patch-Lib-ctypes-macholib-dyld.py.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python39/files/patch-libedit.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python39/files/patch-configure-xcode4bug.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python39/files/sysconfig.py.diff' )
    elif [[ $PYENV == 3.10* ]]; then
        PY_PATCH=( 'https://github.com/macports/macports-ports/raw/master/lang/python310/files/patch-setup.py.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python310/files/patch-Lib-cgi.py.diff'
        # 'https://github.com/macports/macports-ports/raw/master/lang/python310/files/patch-configure.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python310/files/patch-Lib-ctypes-macholib-dyld.py.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python310/files/patch-configure-xcode4bug.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python310/files/sysconfig.py.diff' )
    elif [[ $PYENV == 3.11* ]]; then
        PY_PATCH=( 'https://github.com/macports/macports-ports/raw/master/lang/python310/files/patch-setup.py.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python310/files/patch-Lib-cgi.py.diff'
        # 'https://github.com/macports/macports-ports/raw/master/lang/python310/files/patch-configure.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python310/files/patch-Lib-ctypes-macholib-dyld.py.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python310/files/patch-configure-xcode4bug.diff'
        'https://github.com/macports/macports-ports/raw/master/lang/python310/files/sysconfig.py.diff' )
    fi

    if [[ ! -f "${PYENV_ROOT}/versions/$PYENV/bin/python3" ]]; then
        if [[ $PYENV == pypy* ]]; then
            pyenv install $PYENV
        else
            if [[ "$(uname)" == "Darwin" ]] && [[ $PYENV == 3.8* || $PYENV == 3.7* || $PYENV == 3.6* || $PYENV == 3.5* ]]; then
                env PYTHON_CONFIGURE_OPTS="${Build_PYTHON_CONFIGURE_OPTS}" pyenv install -p $PYENV < <(curl -sSL ${PY_PATCH[@]})
            else
                env PYTHON_CONFIGURE_OPTS="--with-readline=editline ${Build_UNIVERSAL2_PYTHON_CONFIGURE_OPTS}" pyenv install -p $PYENV < <(curl -sSL ${PY_PATCH[@]})
                export Build_MACOSX_REQUIRED_ARCHITECTURES="${REDLIB_MACOSX_ARCHITECTURES}"
            fi
        fi
    fi

    pyenv shell $PYENV
    pyenv versions

    which python3
    python3 -m pip install -U virtualenv
    python3 -m virtualenv -p "${PYENV_VERSION}" "${VENV_ROOT}/${PYENV_VERSION}"

    set +x
    source "${VENV_ROOT}/${PYENV_VERSION}/bin/activate"
    set -x

    python3 -V
    python3 -m pip install -U setuptools pip
    python3 -m pip install -U delocate wheel
    python3 -m pip wheel .
    # \cp /usr/local/lib/libssh2* .
    delocate-listdeps --all ./*.whl
    delocate-wheel -v ./*.whl
    delocate-listdeps --all ./*.whl

    ls -l *.whl
    rm -f *.dylib
    python3 -m pip uninstall -y redlibssh2 || true
    python3 -m pip install -v ./*.whl
    mkdir -p temp; cd temp
    python3 -c "from ssh2.session import Session; Session()" && echo "Import successful"
    cd ..
    set +x
    deactivate
    set -x

    mv -f *.whl wheelhouse/
    ls -lh wheelhouse
done
