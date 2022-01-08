#!/bin/bash

yum -y --disablerepo="epel" install zlib-devel openssl-devel cmake gcc || yum -y install zlib-devel openssl-devel cmake gcc || true
apt && /scripts/setup_manylinux.sh || true
apt update && apt install -y cmake make libssl-dev zlib1g-dev build-essential || true
