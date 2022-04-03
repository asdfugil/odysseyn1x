#!/bin/sh
# Made with <3 by raspberryenvoie
# odysseyn1x build script (a fork of asineth/checkn1x)

# Exit if user isn't root
[ "$(id -u)" -ne 0 ] && {
    echo 'Please run as root'
    exit 1
}

# Change these variables to modify the version of checkra1n
CHECKRA1N_AMD64='https://assets.checkra.in/downloads/linux/cli/x86_64/dac9968939ea6e6bfbdedeb41d7e2579c4711dc2c5083f91dced66ca397dc51d/checkra1n'
CHECKRA1N_I686='https://assets.checkra.in/downloads/linux/cli/i486/77779d897bf06021824de50f08497a76878c6d9e35db7a9c82545506ceae217e/checkra1n'

GREEN="$(tput setaf 2)"
BLUE="$(tput setaf 6)"
NORMAL="$(tput sgr0)"
cat << EOF
${GREEN}############################################${NORMAL}
${GREEN}#                                          #${NORMAL}
${GREEN}#  ${BLUE}Welcome to the odysseyn1x build script  ${GREEN}#${NORMAL}
${GREEN}#                                          #${NORMAL}
${GREEN}############################################${NORMAL}

EOF
# Ask for the version and architecture if variables are empty
while [ -z "$VERSION" ]; do
    printf 'Version: '
    read -r VERSION
done
until [ "$ARCH" = 'amd64' ] || [ "$ARCH" = 'i686' ]; do
    echo '1 amd64'
    echo '2 i686'
    printf 'Which architecture? amd64 (default) or i686 '
    read -r input_arch
    [ "$input_arch" = 1 ] && ARCH='amd64'
    [ "$input_arch" = 2 ] && ARCH='i686'
    [ -z "$input_arch" ] && ARCH='amd64'
done

# Delete old build
{
    umount work/chroot/proc
    umount work/chroot/sys
    umount work/chroot/dev/pts
    umount work/chroot/dev
} > /dev/null 2>&1
rm -rf work/

set -e -u -v
start_time="$(date -u +%s)"

# Install dependencies to build odysseyn1x
apt-get update
apt-get install -y --no-install-recommends wget debootstrap grub-pc-bin \
    grub-efi-amd64-bin mtools squashfs-tools xorriso ca-certificates curl \
    libusb-1.0-0-dev gcc make gzip zstd unzip libc6-dev

if [ "$ARCH" = 'amd64' ]; then
    REPO_ARCH='amd64' # Debian's 64-bit repos are "amd64"
    KERNEL_ARCH='amd64' # Debian's 32-bit kernels are suffixed "amd64"
else
    # Install depencies to build odysseyn1x for i686
    dpkg --add-architecture i386
    apt-get update
    apt install -y --no-install-recommends libusb-1.0-0-dev:i386 gcc-multilib
    REPO_ARCH='i386' # Debian's 32-bit repos are "i386"
    KERNEL_ARCH='686' # Debian's 32-bit kernels are suffixed "-686"
fi

# Configure the base system
mkdir -p work/chroot work/iso/live work/iso/boot/grub
debootstrap --variant=minbase --arch="$REPO_ARCH" testing work/chroot 'http://mirror.xtom.com.hk/debian/'
mkdir -p work/chroot/dev/pts
mount --bind /proc work/chroot/proc
mount --bind /sys work/chroot/sys
mount --bind /dev work/chroot/dev
mount --bind /dev/pts work/chroot/dev/pts

cp /etc/resolv.conf work/chroot/etc
cat << EOF | chroot work/chroot /bin/bash
# Set debian frontend to noninteractive
export DEBIAN_FRONTEND=noninteractive

# Install requiered packages
# We make the phone do the XZ decompression now
apt-get install -y --no-install-recommends linux-image-$KERNEL_ARCH live-boot \
  systemd systemd-sysv usbmuxd libusbmuxd-tools openssh-client sshpass whiptail zstd
EOF
# Change initramfs compression to zstd
sed -i 's/COMPRESS=gzip/COMPRESS=zstd/' work/chroot/etc/initramfs-tools/initramfs.conf
chroot work/chroot /bin/bash -c '/sbin/chpasswd <<< root:pass'
chroot work/chroot update-initramfs -u
chroot work/chroot apt purge -y --allow-remove-essential --autoremove apt zstd gzip
(
    cd work/chroot
    # Empty some directories to make the system smaller
    rm -f etc/mtab \
        etc/fstab \
        etc/ssh/ssh_host* \
        root/.wget-hsts \
        root/.bash_history
    rm -rf var/log/* \
        var/cache/* \
        var/backups/* \
        var/lib/apt/* \
        var/lib/dpkg/* \
        usr/share/doc/* \
        usr/share/man/* \
        usr/share/info/* \
        usr/share/icons/* \
        usr/share/locale/* \
        usr/include/* \
        usr/share/zoneinfo/* \
        usr/lib/modules/* \
        etc/kernel/* \
        usr/sbin/update-initramfs \
        usr/share/bug/* \
        usr/share/lintian/* \
        etc/initramfs-tools/* \
        usr/share/bash-completion/* \
        usr/lib/mime/* \
        usr/lib/lsb/* \
        usr/lib/klibc*
)

# Download A9X resources
mkdir -p work/chroot/opt
cd work/chroot/opt
curl -LO https://cdn.discordapp.com/attachments/672628720497852459/874972423550816306/PongoConsolidated.bin
cd -

# Copy scripts
cp scripts/* work/chroot/usr/bin/

# Download resources for odysseyra1n
mkdir -p work/chroot/root/odysseyra1n/
(
    cd work/chroot/root/odysseyra1n/
    curl -sLOOOOO https://github.com/coolstar/Odyssey-bootstrap/raw/master/bootstrap_1700.tar.gz \
        https://github.com/coolstar/Odyssey-bootstrap/raw/master/bootstrap_1600.tar.gz \
        https://github.com/coolstar/Odyssey-bootstrap/raw/master/bootstrap_1500.tar.gz \
        https://github.com/coolstar/Odyssey-bootstrap/raw/master/org.coolstar.sileo_2.3_iphoneos-arm.deb \
        https://github.com/coolstar/Odyssey-bootstrap/raw/master/org.swift.libswift_5.0-electra2_iphoneos-arm.deb
    # Decompress
    gzip -dv ./*.tar.gz
    tar -c ./*.tar | xz -zvc --lzma2=preset=9,dict=100MB,mf=bt4,mode=normal,nice=273,depth=1000 -T 0 > bootstraps.tar.xz
    rm -f bootstrap_*.tar
)

(
    cd work/chroot/root/
    # Download resources for Android Sandcastle
    curl -L -O 'https://assets.checkra.in/downloads/sandcastle/dff60656db1bdc6a250d3766813aa55c5e18510694bc64feaabff88876162f3f/android-sandcastle.zip'
    unzip android-sandcastle.zip
    rm -f android-sandcastle.zip
    (
        cd android-sandcastle/
        rm -f iproxy ./*.dylib load-linux.mac ./*.sh README.txt
    )

    # Download resources for Linux Sandcastle
    curl -L -O 'https://assets.checkra.in/downloads/sandcastle/0175ae56bcba314268d786d1239535bca245a7b126d62a767e12de48fd20f470/linux-sandcastle.zip'
    unzip linux-sandcastle.zip
    rm -f linux-sandcastle.zip
    (
        cd linux-sandcastle/
        rm -f load-linux.mac README.txt
    )
)

(
    cd work/chroot/usr/bin/
    curl -L -O 'https://raw.githubusercontent.com/corellium/projectsandcastle/master/loader/load-linux.c'
    # Build load-linux.c and download checkra1n for the corresponding architecture
    if [ "$ARCH" = 'amd64' ]; then
        clang -Oz load-linux.c -o load-linux -lusb-1.0
        curl -L -o checkra1n "$CHECKRA1N_AMD64"
    else
        clang -Oz -m32 load-linux.c -o load-linux -lusb-1.0
        curl -L -o checkra1n "$CHECKRA1N_I686"
    fi
    rm -f load-linux.c
    chmod +x load-linux checkra1n
)

# Configure autologin
mkdir -p work/chroot/etc/systemd/system/getty@tty1.service.d
cat << EOF > work/chroot/etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noissue --autologin root %I
Type=idle
EOF

# Configure grub
cat << "EOF" > work/iso/boot/grub/grub.cfg
insmod all_video
echo ''
echo '  ___   __| |_   _ ___ ___  ___ _   _ _ __ / |_  __'
echo ' / _ \ / _` | | | / __/ __|/ _ \ | | | `_ \| \ \/ /'
echo '| (_) | (_| | |_| \__ \__ \  __/ |_| | | | | |>  < '
echo ' \___/ \__,_|\__, |___/___/\___|\__, |_| |_|_/_/\_\'
echo '             |___/              |___/              '
echo ''
echo '          Made with <3 by raspberryenvoie'
linux /boot/vmlinuz boot=live
initrd /boot/initrd.img
boot
EOF

# Change hostname and configure .bashrc
echo 'odysseyn1x' > work/chroot/etc/hostname
echo "export ODYSSEYN1X_VERSION='$VERSION'" > work/chroot/root/.bashrc
echo '/usr/bin/odysseyn1x_menu' >> work/chroot/root/.bashrc

rm -f work/chroot/etc/resolv.conf

# Build the ISO
umount work/chroot/proc
umount work/chroot/sys
umount work/chroot/dev/pts
umount work/chroot/dev
cp work/chroot/vmlinuz work/iso/boot

cp work/chroot/initrd.img work/iso/boot
mksquashfs work/chroot work/iso/live/filesystem.squashfs -noappend -e boot -comp xz -b 64M -Xbcj x86
grub-mkrescue -o "odysseyn1x-$VERSION-$ARCH.iso" work/iso \
    --compress=xz \
    --fonts='' \
    --locales='' \
    --themes=''

end_time="$(date -u +%s)"
elapsed_time="$((end_time - start_time))"

echo "Built odysseyn1x-$VERSION-$ARCH in $((elapsed_time / 60)) minutes and $((elapsed_time % 60)) seconds."
