#!/bin/bash

TOP=$(pwd)

sudo apt-get install -y qemu-user-static
sudo dpkg -i ${TOP}/ubuntu-build-service/packages/live-build_3.0.5-1linaro1_all.deb
sudo apt-get install -y gcc-arm-linux-gnueabihf
sudo apt-get install -y gcc-aarch64-linux-gnu
