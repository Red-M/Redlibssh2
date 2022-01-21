#!/bin/bash

port install cmake +universal
port install pkgconfig +universal
port install ccache +universal
port install openssl +universal
port install openssl11 +universal
# port install python35
# port install python36
# port install python37
# port install python38
port install python39 +universal
# port install python310 +universal
which python3
python3 -c "from __future__ import print_function; import ssl; from platform import python_version; print(ssl.OPENSSL_VERSION); print(python_version())"
./ci/install-ssh2.sh
sudo chown -R $(whoami) ./src
rm ./src/CMakeCache.txt
mkdir -p wheelhouse
ln -s ./wheelhouse ./wheels
pyenv update || curl -L https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash
./ci/gitlab/macos/pyenv-wheel.sh
