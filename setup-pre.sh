#!/bin/bash

TOP=$(pwd)

sudo apt-get install -y qemu-user-static
sudo dpkg -i ${TOP}/ubuntu-build-service/packages/live-build_3.0.5-1linaro1_all.deb
sudo apt-get install -y gcc-arm-linux-gnueabihf
sudo apt-get install -y gcc-aarch64-linux-gnu

# for yocto
sudo apt-get install -y gawk wget git-core diffstat unzip texinfo gcc-multilib build-essential chrpath libsdl1.2-dev xterm nano
