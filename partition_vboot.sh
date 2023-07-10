#!/bin/bash         
                    
DISK="$1"           
                    
# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1          
fi                  
                    
if [ x"$DISK" == 'x' ]; then
    echo "This script requires a base block device as its only arguement" 1>&2
    echo "example: $0 /dev/sdb"
    exit 1          
fi                  
                    
DISK_DEVICE_NAME="$(echo $DISK | awk -F'/' '{print $NF}')"
if [[ "$DISK_DEVICE_NAME" == *mmcblk* ]]; then
    ROOT_PARTITION="$DISK"p2
    SWAP_PARTITION="$DISK"p3
else
    ROOT_PARTITION="$DISK"2
    SWAP_PARTITION="$DISK"3
fi

# TODO allow specify TOTAL_SECTORS
TOTAL_SECTORS=$(cat /sys/block/$DISK_DEVICE_NAME/size)
SECTOR_SIZE=$(cat /sys/block/$DISK_DEVICE_NAME/queue/hw_sector_size)
                    
# the following are in sectors, 1MB = 2048 sectors
FIRST_GAP_SIZE=8192     # 2048 sectors * 4MB
LAST_GAP_SIZE=2048      # 2048 sectors * 1MB
SWAP_PART_SIZE=8388608  # 2048 sectors * 4096MB
KERNEL_PART_SIZE=65536  # 2048 sectors * 32MB
                    
# layout arithmatic 
FIRST_GAP_START=0   
FIRST_GAP_END=$(( $FIRST_GAP_SIZE - 1 ))
KERNEL_PART_START=$(( $FIRST_GAP_END + 1 ))
KERNEL_PART_END=$(( $FIRST_GAP_END + $KERNEL_PART_SIZE ))
ROOTFS_PART_START=$(( $KERNEL_PART_END + 1 ))
                    
LAST_GAP_END=$(( $TOTAL_SECTORS - 1 ))
LAST_GAP_START=$(( $LAST_GAP_END - $LAST_GAP_SIZE + 1 ))
if [ $TOTAL_SECTORS -lt 10000000 ]; then # if size of disk is less than 5GB do not make swap
    MAKESWAP='false' 
    ROOTFS_PART_END=$(( $LAST_GAP_START - 1 ))
    SWAP_PART_END=0
    SWAP_PART_START=0
else
    MAKESWAP='true' 
    SWAP_PART_END=$(( $LAST_GAP_START - 1 ))
    SWAP_PART_START=$(( $SWAP_PART_END - $SWAP_PART_SIZE + 1 ))
    ROOTFS_PART_END=$(( $SWAP_PART_START - 1 ))
fi

echo "TOTAL_SECTORS     = $TOTAL_SECTORS"
echo "SECTOR_SIZE       = $SECTOR_SIZE"
echo ""
echo "FIRST_GAP_SIZE    = $FIRST_GAP_SIZE"
echo "LAST_GAP_SIZE     = $LAST_GAP_SIZE"
echo "SWAP_PART_SIZE    = $SWAP_PART_SIZE"
echo "KERNEL_PART_SIZE  = $KERNEL_PART_SIZE"
echo ""
echo "FIRST_GAP_START   = $FIRST_GAP_START              $(( $FIRST_GAP_START / 2048 )) MB"
echo "FIRST_GAP_END     = $FIRST_GAP_END"
echo "KERNEL_PART_START = $KERNEL_PART_START    $(( $KERNEL_PART_START / 2048 )) MB"
echo "KERNEL_PART_END   = $KERNEL_PART_END"
echo "ROOTFS_PART_START = $ROOTFS_PART_START    $(( $ROOTFS_PART_START / 2048 )) MB"
echo "ROOTFS_PART_END   = $ROOTFS_PART_END"
echo "SWAP_PART_START   = $SWAP_PART_START      $(( $SWAP_PART_START / 2048 )) MB"
echo "SWAP_PART_END     = $SWAP_PART_END"
echo "LAST_GAP_START    = $LAST_GAP_START       $(( $LAST_GAP_START / 2048 )) MB"
echo "LAST_GAP_END      = $LAST_GAP_END"

# use `sgdisk --list-types' to get all possible type codes
KERNEL_PART_TYPE='7f00'
ROOTFS_PART_TYPE='7f01'
SWAP_PART_TYPE='8200'

# wipe disk, and create new gpt partition table
sgdisk --zap-all $DISK
sgdisk -o $DISK

# create the kernel partition
sgdisk --new=1:$KERNEL_PART_START:$KERNEL_PART_END $DISK
sgdisk --typecode=1:$KERNEL_PART_TYPE $DISK
sgdisk --change-name=1:Kernel $DISK
sgdisk --attributes=1:=:015A000000000000 $DISK

# create the rootfs partition 
sgdisk --new=2:$ROOTFS_PART_START:$ROOTFS_PART_END $DISK
sgdisk --typecode=2:$ROOTFS_PART_TYPE $DISK
sgdisk --change-name=2:Root $DISK
mkfs.ext4 $ROOT_PARTITION

# create the swap partition
if [ $MAKESWAP = 'true' ]; then
    sgdisk --new=3:$SWAP_PART_START:$SWAP_PART_END $DISK
    sgdisk --typecode=3:$SWAP_PART_TYPE $DISK
    sgdisk --change-name=3:Swap $DISK
    mkswap $SWAP_PARTITION
fi

sgdisk --print $DISK
lsblk $DISK
