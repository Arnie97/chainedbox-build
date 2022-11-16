#!/bin/bash

set -ex

DTB=dtbs/5.15.y-bsp
IDB=loader/idbloader.bin
UBOOT=loader/uboot.img
TRUST=loader/trust.bin

echo -e "02.01 挂载镜像"
imgfile=$1
blk_dev=$(losetup --show -Pf $imgfile)
mount_point=tmp
mkdir -p $mount_point
mount -v ${blk_dev}p1 $mount_point

echo -e "03.01 复制文件"
cp -v $DTB/*.dtb $mount_point/boot/dtb/rockchip
cp -v l1pro/pwm-fan.service $mount_point/etc/systemd/system/
cp -v l1pro/pwm-fan.pl $mount_point/usr/bin/

echo -e "04.01 修改引导分区相关配置"
sed -i '/^verbosity/cverbosity=7' $mount_point/boot/armbianEnv.txt && \
sed -i '/rootfstype=ext4/a rootflags=rw' $mount_point/boot/armbianEnv.txt && \
echo "extraargs=usbcore.autosuspend=-1" >> $mount_point/boot/armbianEnv.txt && \
echo "extraboardargs=" >> $mount_point/boot/armbianEnv.txt && \
echo "fdtfile=rockchip/rk3328-l1pro-1296mhz.dtb" >> $mount_point/boot/armbianEnv.txt && \
echo "usbstoragequirks=0x05e3:0x0612:u,0x1d6b:0x0003:u,0x05e3:0x0610:u" >> $mount_point/boot/armbianEnv.txt && \
sed -i 's/0x9000000/0x39000000/' $mount_point/boot/boot.cmd && \
sed -i 's#${prefix}dtb/${fdtfile}#${prefix}/${fdtfile}#' $mount_point/boot/boot.cmd
mkimage -C none -T script -d $mount_point/boot/boot.cmd $mount_point/boot/boot.scr

rm -f $mount_point/etc/systemd/system/getty.target.wants/serial-getty\@ttyS2.service

umount -f $mount_point
losetup -D

echo "添加引导项： idb,uboot,trust"
dd if=${IDB} of=${imgfile} seek=64 bs=512 conv=notrunc status=none && echo "idb patched: ${IDB}" || { echo "idb patch failed!"; exit 1; }
dd if=${UBOOT} of=${imgfile} seek=16384 bs=512 conv=notrunc status=none && echo "uboot patched: ${UBOOT}" || { echo "u-boot patch failed!"; exit 1; }
dd if=${TRUST} of=${imgfile} seek=24576 bs=512 conv=notrunc status=none && echo "trust patched: ${TRUST}" || { echo "trust patch failed!"; exit 1; }
