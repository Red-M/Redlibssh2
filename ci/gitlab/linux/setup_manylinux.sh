#!/bin/bash

yum -y --disablerepo="epel" install zlib-devel openssl-devel cmake gcc || yum -y install zlib-devel openssl-devel cmake gcc || true
yum -y --disablerepo="epel" update || yum -y update || true
apt && /scripts/install_deb_mirror.sh || true
apt update && apt install -y cmake make libssl-dev zlib1g-dev build-essential && apt upgrade -y || true
