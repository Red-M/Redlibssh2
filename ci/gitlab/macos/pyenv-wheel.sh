#!/bin/bash -xe

export BUILD_PYENV_VERSIONS=("${PYENV:-ALL}")
export PYENV_ROOT="${HOME}/${MACOSX_DEPLOYMENT_TARGET}/.pyenv"
export PATH="${PYENV_ROOT}/bin:${PATH}"
ALL_PYENV_VERSION_DEFAULT=("ALL")
ALL_BUILD_PYENV_VERSIONS=("3.9.7" "3.8.12" "3.7.12" "3.6.14" "3.5.10" "2.7.18")
# ALL_BUILD_PYENV_VERSIONS=("3.9.7" "3.8.12" "3.7.12" "3.6.14" "3.5.10" "2.7.18" "pypy3.7-7.3.5" "pypy3.6-7.3.3" "pypy2.7-7.3.1")
# ALL_BUILD_PYENV_VERSIONS=("3.9.7" "3.8.13" "3.7.13")

if [ ${BUILD_PYENV_VERSIONS[@]} = ${ALL_PYENV_VERSION_DEFAULT[@]} ]; then
    BUILD_PYENV_VERSIONS=(${ALL_BUILD_PYENV_VERSIONS[@]})
fi

set +x
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
set -x
if [[ ! -d "./venv" ]]; then
    mkdir ./venv
fi

for PYENV in ${BUILD_PYENV_VERSIONS[@]}; do
    if [[ ! -d "${PYENV_ROOT}/versions/$PYENV" ]]; then
        if [[ "$(uname)" == "Darwin" ]] && [[ $PYENV == 3.6* || $PYENV == 3.5* || $PYENV == 2.7* ]]; then
            pyenv install --patch $PYENV < <(curl -sSL 'https://github.com/python/cpython/commit/8ea6353.patch?full_index=1')
        else
            pyenv install $PYENV
        fi
    fi

    pyenv shell $PYENV
    pyenv versions

    which python
    python -m pip install -U virtualenv
    python -m virtualenv -p "${PYENV_VERSION}" "venv/${PYENV_VERSION}"

    set +x
    source "venv/${PYENV_VERSION}/bin/activate"
    set -x

    python -V
    python -m pip install -U setuptools pip
    pip install -U delocate wheel
    pip wheel .
    # \cp /usr/local/lib/libssh2* .
    delocate-listdeps --all ./*.whl
    delocate-wheel --require-archs ${MACOSX_REQUIRED_ARCHITECTURES} -v ./*.whl
    delocate-listdeps --all ./*.whl

    ls -l *.whl
    rm -f *.dylib
    pip install -v ./*.whl
    mkdir -p temp; cd temp
    python -c "from ssh2.session import Session; Session()" && echo "Import successful"
    cd ..
    set +x
    deactivate
    set -x

    mv -f *.whl wheelhouse/
    ls -lh wheelhouse
done
