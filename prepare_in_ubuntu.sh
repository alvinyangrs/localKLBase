#!/bin/bash

apt update
apt install -y git
cd /mnt3
git config --global core.compression 0
git clone --recurse-submodules https://github.com/alvinyangrs/localKLBase.git

