#!/bin/bash

brew cleanup
brew update
brew install cmake ccache
brew outdated openssl || brew upgrade openssl || echo "y"
brew link --overwrite python@3.9 || brew install python@3.9 || brew link --overwrite python@3.9
which python3
python3 -c "from __future__ import print_function; import ssl; from platform import python_version; print(ssl.OPENSSL_VERSION); print(python_version())"
./ci/install-ssh2.sh
sudo chown -R $(whoami) ./src
rm ./src/CMakeCache.txt
mkdir -p wheelhouse
ln -s ./wheelhouse ./wheels
brew install pyenv || brew outdated pyenv || brew upgrade pyenv
./ci/gitlab/macos/pyenv-wheel.sh
