#!/bin/bash -xe

brew install pyenv || brew outdated pyenv || brew upgrade pyenv

export PYENV_VERSION=("${PYENV:-ALL}")
ALL_PYENV_VERSION_DEFAULT=("ALL")
ALL_PYENV_VERSIONS=("3.9.6" "3.8.11" "3.7.11" "3.6.14" "3.5.10")

if [ ${PYENV_VERSION[@]} = ${ALL_PYENV_VERSION_DEFAULT[@]} ]; then
    PYENV_VERSION=(${ALL_PYENV_VERSIONS[@]})
fi

if [[ ! -d "$HOME/.pyenv/versions/$PYENV_VERSION" ]]; then
    pyenv install $PYENV_VERSION
fi
pyenv global $PYENV_VERSION
pyenv versions

set +x
eval "$(pyenv init -)"
set -x

which python
python -m pip install -U virtualenv
python -m virtualenv -p "$(which python)" venv

set +x
source venv/bin/activate
set -x

python -V
python -m pip install -U setuptools pip
pip install -U delocate wheel
pip wheel .
cp /usr/local/lib/libssh2* .
delocate-listdeps --all *.whl
delocate-wheel -v *.whl
delocate-listdeps --all *.whl

ls -l *.whl
rm -f *.dylib
pip install -v *.whl
pwd; mkdir -p temp; cd temp; pwd
python -c "from ssh2.session import Session; Session()" && echo "Import successfull"
cd ..; pwd
set +x
deactivate
set -x

mv -f *.whl wheels/
ls -lh wheels
