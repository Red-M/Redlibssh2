#!/bin/bash


if [ ! -z $(getent hosts deb-mirror | awk '{ print $1 }') ]; then
    VERSION_CODENAME=$(grep VERSION_CODENAME /etc/os-release | sed -E 's/.+?\=//g')
    echo "deb http://deb-mirror/deb.debian.org/debian ${VERSION_CODENAME} main non-free contrib
deb-src http://deb-mirror/deb.debian.org/debian ${VERSION_CODENAME} main non-free contrib
deb http://deb-mirror/deb.debian.org/debian ${VERSION_CODENAME}-updates main contrib non-free
deb-src http://deb-mirror/deb.debian.org/debian ${VERSION_CODENAME}-updates main contrib non-free
$(cat /etc/apt/sources.list)" > /etc/apt/sources.list
fi
