#!/bin/bash

set -e

TOP=`pwd`
RESULT_DIR=${TOP}/result
export TOP RESULT_DIR

BUILD_ALL=true
BUILD_UBOOT=false
BUILD_KERNEL=false
BUILD_UBUNTU=false

BOARD_NAME=
CHIP_NAME=
BOARD_PURE_NAME=
ARCH=arm64
TOOLCHAIN=
UBUNTU_BUILD_DIR=

KERNEL_VERSION=3.18

function check_result()
{
    job=$1
    if [ $? -ne 0 ]; then
        echo "Error in job ${job}"
        exit 1
    fi
}

function usage()
{
    echo "Usage: $0 -b <board-name> -a <arm-architecture> -k <kernel-version> -t u-boot -t kernel -t ubuntu"
    echo -e '\n -b <board-name> : target board name (need for build u-boot, kernel)'
    echo " -a <arm-architecture> : arm64 or arm, default arm64"
    echo " -k <kernel-version> : 3.4.39 or 3.18, default 3.18"
    echo " -t u-boot  : if you want to build only u-boot, specify this, default no"
    echo " -t kernel  : if you want to build only kernel, specify this, default no"
    echo " -t ubuntu  : if you want to build only kernel, specify this, default no"
    echo " -t none    : if you want to only post process, specify this, default no"
}

function parse_args()
{
    TEMP=`getopt -o "b:a:t:k:h" -- "$@"`
    eval set -- "$TEMP"

    while true; do
        case "$1" in
            -b ) BOARD_NAME=$2; shift 2 ;;
            -t ) case "$2" in
                    u-boot  ) BUILD_ALL=false; BUILD_UBOOT=true ;;
                    kernel  ) BUILD_ALL=false; BUILD_KERNEL=true ;;
                    ubuntu  ) BUILD_ALL=false; BUILD_UBUNTU=true ;;
                    none    ) BUILD_ALL=false ;;
                 esac
                 shift 2 ;;
            -a ) case "$2" in
                    arm     ) ARCH=arm ;;
                    arm64   ) ARCH=arm64 ;;
                 esac
                 shift 2 ;;
            -k ) case "$2" in
                    3.18    ) KERNEL_VERSION=3.18 ;;
                    3.4.39  ) KERNEL_VERSION=3.4.39 ;;
                 esac
                 shift 2 ;;
            -h ) usage; exit 1 ;;
            -- ) break ;;
            *  ) echo "invalid option $1"; usage; exit 1 ;;
        esac
    done
}

function print_args()
{
    echo "=============================================="
    echo " BUILD VARIABLES"
    echo "=============================================="
    echo -e "BOARD_NAME:\t\t${BOARD_NAME}"
    if [ ${BUILD_ALL} == "true" ]; then
        echo -e "Build:\t\t\tAll"
    else
        if [ ${BUILD_UBOOT} == "true" ]; then
            echo -e "Build:\t\t\tu-boot"
        fi
        if [ ${BUILD_KERNEL} == "true" ]; then
            echo -e "Build:\t\t\tkernel"
        fi
        if [ ${BUILD_UBUNTU} == "true" ]; then
            echo -e "Build:\t\t\tubuntu"
        fi
    fi
    echo -e "ARCH:\t\t\t${ARCH}"
    echo -e "KERNEL_VERSION:\t\t${KERNEL_VERSION}"
}

function get_chip_name()
{
    CHIP_NAME=${BOARD_NAME%_*}
}

function get_board_pure_name()
{
    BOARD_PURE_NAME=${BOARD_NAME#*_}
}

function setup_toolchain()
{
    if [ "${ARCH}"  == "arm64" ]; then
        TOOLCHAIN=aarch64-linux-gnu-
    else
        TOOLCHAIN=arm-linux-gnueabihf-
    fi
}

function build_uboot()
{
    if [ ${BUILD_ALL} == "true" ] || [ ${BUILD_UBOOT} == "true" ]; then
        echo ""
        echo "=============================================="
        echo "build u-boot"
        echo "=============================================="

        if [ ! -e ${TOP}/u-boot ]; then
            cd ${TOP}
            ln -s linux/bootloader/u-boot-2014.07 u-boot
        fi

        cd ${TOP}/u-boot
        make distclean

        if [ "${ARCH}"  == "arm64" ]; then
            make ${CHIP_NAME}_arm64_${BOARD_PURE_NAME}_config
        else
            make ${CHIP_NAME}_${BOARD_PURE_NAME}_config
        fi
        CROSS_COMPILE=${TOOLCHAIN} make -j8
        check_result "build-uboot"

        cd ${TOP}

        echo "---------- End of build u-boot"
    fi
}

function build_kernel()
{
    if [ ${BUILD_ALL} == "true" ] || [ ${BUILD_KERNEL} == "true" ]; then
        echo ""
        echo "=============================================="
        echo "build kernel"
        echo "=============================================="

        cd ${TOP}
        rm -f kernel
        ln -s linux/kernel/kernel-${KERNEL_VERSION} kernel

        cd ${TOP}/kernel

        local kernel_config=${CHIP_NAME}_${BOARD_PURE_NAME}_ubuntu_defconfig

        make distclean
        yes "" | make ARCH=arm oldconfig
        if [ "${ARCH}"  == "arm64" ]; then
            cp arch/arm64/configs/${kernel_config} .config
            CROSS_COMPILE=${TOOLCHAIN} make ARCH=arm64 Image -j8
            CROSS_COMPILE=${TOOLCHAIN} make ARCH=arm64 nexell/${CHIP_NAME}-${BOARD_PURE_NAME}.dtb
        else
            cp arch/arm/configs/${kernel_config} .config
            if [ "${KERNEL_VERSION}"  == "3.18" ]; then
                CROSS_COMPILE=${TOOLCHAIN} make ARCH=arm zImage -j8
                CROSS_COMPILE=${TOOLCHAIN} make ARCH=arm nexell/${CHIP_NAME}-${BOARD_PURE_NAME}.dtb
            else
                CROSS_COMPILE=${TOOLCHAIN} make ARCH=arm uImage -j8
            fi
        fi

        check_result "build-kernel"

        echo "---------- End of build kernel"
    fi
}

function build_ubuntu()
{
    if [ ${BUILD_ALL} == "true" ] || [ ${BUILD_UBUNTU} == "true" ]; then
        echo ""
        echo "=============================================="
        echo "build ubuntu"
        echo "=============================================="

        local build_dir=
        if [ "${ARCH}" == "arm64" ]; then
            build_dir=vivid-arm64-gnome
        else
            build_dir=vivid-armhf-gnome
        fi
        UBUNTU_BUILD_DIR=${TOP}/ubuntu-build-service/${build_dir}
        cd ${UBUNTU_BUILD_DIR}
        ./configure
        make

        cd ${TOP}

        echo "---------- End of build ubuntu"
    fi
}

function make_boot()
{
    mkdir -p ${RESULT_DIR}/boot

    if [ "${ARCH}"  == "arm64" ]; then
        cp ${TOP}/kernel/arch/arm64/boot/Image ${RESULT_DIR}/boot
        cp ${TOP}/kernel/arch/arm64/boot/dts/nexell/${CHIP_NAME}-${BOARD_PURE_NAME}.dtb ${RESULT_DIR}/boot
    else
        if [ "${KERNEL_VERSION}"  == "3.18" ]; then
            cp ${TOP}/kernel/arch/arm/boot/zImage ${RESULT_DIR}/boot
            cp ${TOP}/kernel/arch/arm/boot/dts/nexell/${CHIP_NAME}-${BOARD_PURE_NAME}.dtb ${RESULT_DIR}/boot
        else
            cp ${TOP}/kernel/arch/arm/boot/uImage ${RESULT_DIR}/boot
        fi
    fi
}

function make_root()
{
    mkdir -p ${RESULT_DIR}/root
    cp -a ${UBUNTU_BUILD_DIR}/binary/* ${RESULT_DIR}/root
    sudo chown -R 1000:1000 ${RESULT_DIR}/root/*
}

function post_process()
{
    echo ""
    echo "=============================================="
    echo "post processing"
    echo "=============================================="

    rm -rf ${RESULT_DIR}
    mkdir -p ${RESULT_DIR}

    cp ${TOP}/u-boot/u-boot.bin ${RESULT_DIR}

    make_boot
    make_root

    echo "---------- End of post processing"
}

parse_args $@
print_args
get_chip_name
get_board_pure_name
setup_toolchain
build_uboot
build_kernel
build_ubuntu
# post_process
