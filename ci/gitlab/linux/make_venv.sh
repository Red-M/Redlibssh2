#!/bin/bash

if [ ! -d ~/.venvs ]; then
    mkdir -p ~/.venvs
fi

if [ ! -d ~/.venvs/redlibssh2 ]; then
    python3 -m venv ~/.venvs/redlibssh2
fi
