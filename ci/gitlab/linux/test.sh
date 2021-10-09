#!/bin/bash

apt update && apt install -y make curl wget openssh-client openssh-server git cmake libssl-dev zlib1g-dev
apt install -y python3 python3-dev python3-distutils python3-setuptools cython3
wget -O get-pip.py "https://bootstrap.pypa.io/get-pip.py"
python3 ./get-pip.py
git submodule update --init --recursive
pip3 install -U readme-renderer
python3 -m readme_renderer ./README.rst -o /tmp/README.html
\rm ./ssh2/*.c
python3 setup.py build_ext --inplace
pip install -e .[tests]
