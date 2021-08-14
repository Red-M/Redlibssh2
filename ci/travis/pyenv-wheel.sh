#!/bin/bash -xe

brew install pyenv || brew outdated pyenv || brew upgrade pyenv

export BUILD_PYENV_VERSIONS=("${PYENV:-ALL}")
ALL_PYENV_VERSION_DEFAULT=("ALL")
# ALL_BUILD_PYENV_VERSIONS=("3.9.6" "3.8.11" "3.7.11" "3.6.14" "3.5.10")
ALL_BUILD_PYENV_VERSIONS=("3.9.6" "3.8.11" "3.7.11")

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
    if [[ ! -d "$HOME/.pyenv/versions/$PYENV" ]]; then
        pyenv install $PYENV
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
    \cp /usr/local/lib/libssh2* .
    delocate-listdeps --all ./*.whl
    delocate-wheel -v ./*.whl
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
