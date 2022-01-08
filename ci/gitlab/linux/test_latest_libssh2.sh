#!/bin/bash
PATH=$PATH:~/.local/bin
CI_SYSTEM=${1}
PYTHON_VERSION=${2}

apt update && apt install -y make curl wget openssh-client openssh-server git cmake libssl-dev zlib1g-dev build-essential
apt install -y python3 python3-dev python3-distutils python3-setuptools cython3
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
pip install redssh[tests]
git clone https://github.com/Red-M/RedSSH.git /tmp/redssh
cp -r /tmp/redssh/tests ./tests
\rm -rf /tmp/redssh


if [ -n $CI_SYSTEM ] && [ ${CI_SYSTEM} == "GITLAB" ]; then
    sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
    echo "export VISIBLE=now" >> /etc/profile
    source /etc/profile
    mkdir /var/run/sshd || true
fi

if [ -n $CI_SYSTEM ]; then
    mkdir /run/sshd || true
fi

if [ ! -z $CI_SYSTEM ] && [ ${CI_SYSTEM} != "LOCAL" ]; then
    export GIT_BRANCH=${CI_COMMIT_BRANCH}
    eval "$(ssh-agent \-s)"
    chmod 600 ./tests/ssh_host_key
    ssh-add ./tests/ssh_host_key
fi


if [ -n $CI_SYSTEM ] && [ ${CI_SYSTEM} == "GITLAB" ]; then
    chmod 700 /builds /builds/Red_M
    export LC_ALL=C.UTF-8
    export LANG=C.UTF-8
fi

if [ ! -z $CI_SYSTEM ] && [ ${CI_SYSTEM} == "TRAVIS" ]; then
    pip${PYTHON_VERSION} install --upgrade pytest coveralls pytest-cov pytest-xdist paramiko > /dev/null
    py.test --cov redlibssh2
else
    pip${PYTHON_VERSION} install --upgrade --user pytest coveralls pytest-cov pytest-xdist paramiko > /dev/null
    py.test --cov redlibssh2 --cov-config .coveragerc
fi

echo "*********** Coverage ***********"
coverage html
if [ ! -z $CI_SYSTEM ]; then
    coveralls || true
fi

CODE_VALIDATION_PY_FILES="$(find ./ssh2 -type f | grep -E '\.py(x|)$' | grep -v 'tests/' | grep -v '\_version\.py')" # Ignore tests for now.
BANDIT_REPORT=$(tempfile)
PYLINT_REPORT=$(tempfile)
SAFETY_REPORT=$(tempfile)
echo "*********** Bandit ***********"
bandit -c ./.bandit.yml -r ${CODE_VALIDATION_PY_FILES} 2>&1 > "${BANDIT_REPORT}"
cat "${BANDIT_REPORT}"

echo "*********** Pylint ***********"
pylint ${CODE_VALIDATION_PY_FILES} 2>&1 > "${PYLINT_REPORT}"
cat "${PYLINT_REPORT}"

echo "*********** Safety ***********"
safety check 2>&1 > "${SAFETY_REPORT}"
cat "${SAFETY_REPORT}"
