#!/bin/bash

apt update && apt install -y make curl wget openssh-client openssh-server git cmake libssl-dev zlib1g-dev
apt install -y python3 python3-dev python3-distutils
wget -O get-pip.py "https://bootstrap.pypa.io/get-pip.py"
python3 ./get-pip.py
pip3 install -U readme-renderer
python3 -m readme_renderer ./README.rst -o /tmp/README.html
git submodule update --init --recursive
cd ./libssh2
git checkout master
git pull origin master
cd ../
python3 setup.py build_ext --inplace
