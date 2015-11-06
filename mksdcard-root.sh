#!/bin/bash

ROOTDEV=$1

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
    mkdir -p mnt
    sudo mount -t vfat ${ROOTDEV}"1" mnt
    sudo cp boot/* mnt
    sync
    sudo umount mnt
}

function make_root()
{
    mkdir -p mnt
    sudo mount -t ext4 ${ROOTDEV}"2" mnt
    sudo cp -a binary/* mnt
    sudo chown -R 1000:1000 mnt/*
    sync
    sudo umount mnt
}

if [ $ROOTDEV ]
then
    cleanup_sd
    rm -rf mnt/*
	format_sd
    make_boot
    make_root
else
	echo "Error!!! You must specify sd card device node (check df, normally /dev/sdb)"
	echo "Usage: $0 sdcard-device-node"
	echo "ex) $0 /dev/sdb"
fi
