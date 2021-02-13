#!/bin/bash


if [ ! -z $(getent hosts deb-mirror | awk '{ print $1 }') ]; then
    echo "deb http://deb-mirror/deb.debian.org/debian stable main non-free contrib
deb-src http://deb-mirror/deb.debian.org/debian stable main non-free contrib
deb http://deb-mirror/deb.debian.org/debian stable-updates main contrib non-free
deb-src http://deb-mirror/deb.debian.org/debian stable-updates main contrib non-free
$(cat /etc/apt/sources.list)" > /etc/apt/sources.list
fi
