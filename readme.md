## Setting up the Asus Chromebook c201 with libreboot and archlinux arm

#### Stage 0: Get prerequisite files

```
pacman -S gptfdisk uboot-tools vboot-utils

if not on alarm, install from AUR: https://aur.archlinux.org/packages/vboot-utils
```

```
git clone https://github.com/mai-gh/speedy-config && cd speedy-config

mkdir libreboot_c201 && cd libreboot_c201
wget -c https://libreboot.org/lbkeyold.asc
gpg --import lbkeyold.asc
wget -c https://mirror.math.princeton.edu/pub/libreboot/stable/20160907/SHA512SUMS.sig
wget -c https://mirror.math.princeton.edu/pub/libreboot/stable/20160907/SHA512SUMS
gpg --verify SHA512SUMS.sig
mkdir -p rom/depthcharge/
wget -c -P rom/depthcharge/ https://mirror.math.princeton.edu/pub/libreboot/stable/20160907/rom/depthcharge/libreboot_r20160907_depthcharge_veyron_speedy.tar.xz
sha512sum --check --ignore-missing SHA512SUMS
cd ..

# manually verify keys here: https://archlinuxarm.org/about/package-signing
gpg --recv-keys 68B3537F39A313B3E574D06777193F152BDBE6A6
mkdir alarm_20230302 && cd alarm_20230302
wget -c http://tardis.tiny-vps.com/aarm/repos/2023/03/02/os/ArchLinuxARM-armv7-latest.tar.gz
wget -c http://tardis.tiny-vps.com/aarm/repos/2023/03/02/os/ArchLinuxARM-armv7-latest.tar.gz.md5
wget -c http://tardis.tiny-vps.com/aarm/repos/2023/03/02/os/ArchLinuxARM-armv7-latest.tar.gz.sig
md5sum --check ArchLinuxARM-armv7-latest.tar.gz.md5
gpg --verify ArchLinuxARM-armv7-latest.tar.gz.sig
wget -c http://tardis.tiny-vps.com/aarm/repos/2023/03/02/armv7h/core/dialog-1%3A1.3_20230209-1-armv7h.pkg.tar.xz
wget -c http://tardis.tiny-vps.com/aarm/repos/2023/03/02/armv7h/core/dialog-1%3A1.3_20230209-1-armv7h.pkg.tar.xz.sig
gpg --verify "dialog-1:1.3_20230209-1-armv7h.pkg.tar.xz.sig"
wget -c http://tardis.tiny-vps.com/aarm/repos/2023/03/02/armv7h/core/wpa_supplicant-2%3A2.10-8-armv7h.pkg.tar.xz
wget -c http://tardis.tiny-vps.com/aarm/repos/2023/03/02/armv7h/core/wpa_supplicant-2%3A2.10-8-armv7h.pkg.tar.xz.sig
gpg --verify "wpa_supplicant-2:2.10-8-armv7h.pkg.tar.xz.sig"
wget -c http://tardis.tiny-vps.com/aarm/repos/2023/03/02/armv7h/community/pcsclite-1.9.9-2-armv7h.pkg.tar.xz
wget -c http://tardis.tiny-vps.com/aarm/repos/2023/03/02/armv7h/community/pcsclite-1.9.9-2-armv7h.pkg.tar.xz.sig
gpg --verify pcsclite-1.9.9-2-armv7h.pkg.tar.xz.sig
cd ..

# at the time of writing, alarm sources are not available, so we will use parabola's sources
git clone https://git.parabola.nu/abslibre.git
# checkout about the same date as the rootfs from alarm
git -C abslibre checkout ca9c36b98d498963476c0732d54c219fa4ce85cc

```


#### Stage 1: Chrome OS, Libreboot, Blob backups

 - Boot into recovery mode by pressing Escape + Refresh + Power when the device is off.
 - Press Ctrl + D, then Enter to enable developer mode. wait for it to do its thing.
 - when rebooted, click Enable Debugging Features -> Proceed 
 - let it reboot, then set the root password
 - poweroff and remove the write protect screw https://web.archive.org/web/20191017100107/https://libreboot.org/docs/install/c201.html#removing-the-write-protect-screw, power back on, wait to boot ( Press Ctrl+D to skip the 30 second timeout)
 - press Ctrl + Alt + Refresh to get a tty, login as root
 - `crossystem dev_boot_signed_only=0`
 - `crossystem dev_boot_usb=1`
 - copy over libreboot_r20160907_depthcharge_veyron_speedy.tar.xz via a usb drive
 - tar -xvf libreboot_r20160907_depthcharge_veyron_speedy.tar.xz && cd libreboot_r20160907_depthcharge_veyron_speedy
 - `flashrom -p host -r stock_flash.img`
 - backup stock_flash.img to your usb drive, as a backup of the original
 - backup the wifi blobs: `tar -cvzf wifi.tgz --dereference /lib/firmware/brcm`
 - backup wifi.tgz to your usb drive
 - `cp stock_flash.img libreboot_c201.img`
 - `./cros-flash-replace libreboot_c201.img coreboot ro-frid`
 - `flashrom -p host -w libreboot_c201.img`

#### Stage 2: Create a bootable USB of Archlinux arm

```
./partition_vboot.sh /dev/sdX
mount /dev/sdX2 /mnt/usb
bsdtar -xf alarm_20230302/ArchLinuxARM-armv7-latest.tar.gz -C /mnt/usb
tar -xvzf blobs_backup/wifi.tgz -C /mnt/usb
rm /mnt/usb/lib/firmware/brcm/brcmfmac4354-sdio.clm_blob
cp "alarm_20230302/dialog-1:1.3_20230209-1-armv7h.pkg.tar.xz" /mnt/usb/root/
cp "alarm_20230302/wpa_supplicant-2:2.10-8-armv7h.pkg.tar.xz" /mnt/usb/root/
cp "alarm_20230302/pcsclite-1.9.9-2-armv7h.pkg.tar.xz" /mnt/usb/root/
mkdir /mnt/usb/boot/pack
cp abslibre/libre/linux-libre/kernel.keyblock /mnt/usb/boot/pack/
cp abslibre/libre/linux-libre/kernel_data_key.vbprivk /mnt/usb/boot/pack/
cp cmdline /mnt/usb/boot/pack/
cp kernel.its /mnt/usb/boot/pack/
cp pack_vboot.sh /mnt/usb/boot/pack/
cd /mnt/usb/boot/pack
dd if=/dev/zero of=bootloader.bin bs=512 count=1
mkimage -f kernel.its kernel.itb
./pack_vboot.sh
dd if=vmlinux.kpart of=/dev/sda1
cd
sync
umount /mnt/usb
```

#### Stage 3: Boot Alarm, Connect to the internet, Setup install environment

 - now boot the drive on the c201, when it boots to the libreboot screen press ctrl + u to boot from the usb
 - login as root
```
pacman -U *.pkg.tar.xz
wifi-menu
pacman-key --init
pacman -Sy archlinux-keyring archlinuxarm-keyring
# it will fail and ask you to delete, dont
rm /var/cache/pacman/pkg/*keyring*sig
pacman -U /var/cache/pacman/*keyring*
# we do this again twice to ensure that all system keys are authentic their packages verify like normal
pacman -Sy archlinux-keyring archlinuxarm-keyring
pacman -Sy archlinux-keyring archlinuxarm-keyring

pacman -S arch-install-scripts vboot-utils uboot-tools gptfdisk vim mc git

git clone https://github.com/mai-gh/speedy-config 
cd speedy-config
./clone_abslibre.sh
```

#### Stage 4: Install to emmc

TODO


#### Restoring Chrome OS

Download one of the speedy zips from https://googleapps.chatham-nj.org/CrOS/

unzip and dd the bin to a usb drive, then boot it on the c201

#### Information Sources
 - https://web.archive.org/web/20200227082857/https://libreboot.org/docs/depthcharge/
 - https://web.archive.org/web/20191017100107/https://libreboot.org/docs/install/c201.html
 - https://wiki.parabola.nu/User:Mai
 - https://github.com/urjaman/arch-c201
