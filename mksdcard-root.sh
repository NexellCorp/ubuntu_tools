#!/bin/bash

ROOTDEV=$1
TOP=$(pwd)
RESULT_DIR=${TOP}/result
MOUNT_DIR=${RESULT_DIR}/mnt

function cleanup_sd {
	echo ""
	echo "Unmounting Partitions"
	echo ""

	NUM_MOUNTS=$(mount | grep -v none | grep "$ROOTDEV" | wc -l)

	for (( c=1; c<=$NUM_MOUNTS; c++ ))
	do  
		DRIVE=$(mount | grep -v none | grep "$ROOTDEV" | tail -1 | awk '{print $1}')
		sudo umount ${DRIVE} &> /dev/null || true
	done

	sudo dd if=/dev/zero of=$ROOTDEV bs=1M count=10
	sync
}

function format_sd()
{
	echo 
	echo '==============================================='
	echo "        Format SD: $ROOTDEV					 "
	echo '==============================================='	
	cleanup_sd
	sudo fdisk -H 255 -S 63 $ROOTDEV << END
n
p
1

+1G
t
b
n
p



w
END
	sync
	sudo mkfs.vfat -n boot $ROOTDEV"1"
	sudo mkfs.ext4 -L root $ROOTDEV"2"
	sync
}

function make_boot()
{
    mkdir -p ${MOUNT_DIR}
    echo "result dir ---> ${RESULT_DIR}"
    sudo mount -t vfat ${ROOTDEV}"1" ${MOUNT_DIR}
    sudo cp ${RESULT_DIR}/boot/* ${MOUNT_DIR}/
    sync
    sudo umount ${MOUNT_DIR}
}

function patch_root()
{
    cd ${TOP}
    local patch_dir=${TOP}/tools/patch
    local patch_list_file=${patch_dir}/files.txt
    local src_file=""
    local dst_dir=""
    while read line; do
        src_file=$(echo ${line} | awk '{print $1}')
        dst_dir=$(echo ${line} | awk '{print $2}')
        echo "copy ${patch_dir}/${src_file}  =====> ${MOUNT_DIR}/${dst_dir}"
        cp ${patch_dir}/${src_file} ${MOUNT_DIR}/${dst_dir}
    done < ${patch_list_file}
    cd ${TOP}
}

function make_root()
{
    mkdir -p ${MOUNT_DIR}
    sudo mount -t ext4 ${ROOTDEV}"2" ${MOUNT_DIR}
    sudo chown -R 1000:1000 ${MOUNT_DIR}
    tar xvzf ${RESULT_DIR}/*.gz -C ${RESULT_DIR}/
    cp -a ${RESULT_DIR}/binary/* ${MOUNT_DIR}

    patch_root

    sync
    sudo umount ${MOUNT_DIR}
}

if [ $ROOTDEV ]
then
    cleanup_sd
    rm -rf ${MOUNT_DIR}/*
	format_sd
    sleep 1
    make_boot
    make_root
else
	echo "Error!!! You must specify sd card device node (check df, normally /dev/sdb)"
	echo "Usage: $0 sdcard-device-node"
	echo "ex) $0 /dev/sdb"
fi
