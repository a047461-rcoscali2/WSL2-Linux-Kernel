#!/bin/bash
set -ueo pipefail

if [ $# -ne 3 ] || [ ! -d "$1" ]; then
	printf '%s' "Usage ./$0 <modules dir> <kernelversion> <output file>" 1>&2
	exit 1
fi

if [ -e "$3" ]; then
	printf '%s' "Refusing to overwrite existing file $3" 1>&2
	exit 2
fi

if test -z "$USE_SUDO";
then
    echo "Define the USE_SUDO env var to specify if you want to use or not sudo" 2>
    echo "For using 'sudo' define $ export USE_SUDO=yes" 2>
    echo "For not using 'sudo' define export USE_SUDO=no (but you'll have to 'sudo gen_modules_vhdx.sh ...')" 2>
else
    if test "$USE_SUDO" == "yes"
    then
        SUDO_CMD=sudo
    else if test "$USE_SUDO" == "no"
         then
             SUDO_CMD=
         else
             echo "USE_SUDO shall be 'yes' or 'no'"
         fi
    fi
fi

# Calculate modules size (+ 256MiB for slack)
modules_size=$(du -bs "$1" | awk '{print $1;}')
modules_size=$((modules_size + (320*(1<<20))))

# Create our scratch directory
tmp_dir=$(mktemp -d)

# Create a blank image file of the right size
dd if=/dev/zero of="$tmp_dir/modules.img" bs=1024 count=$((modules_size / 1024))

# Set up fs and mount
lo_dev=$($SUDO_CMD losetup --find --show "$tmp_dir/modules.img")
$SUDO_CMD mkfs -t ext4 "$lo_dev"
mkdir "$tmp_dir/modules_img"
$SUDO_CMD mount "$lo_dev" "$tmp_dir/modules_img"
$SUDO_CMD chmod a+rw "$tmp_dir/modules_img"

# Copy over the contents of $1
cp -r "$1/lib/modules/$2"/* "$tmp_dir/modules_img"
sync
$SUDO_CMD umount "$tmp_dir/modules_img"

# Do the final conversion
qemu-img convert -O vhdx "$tmp_dir/modules.img" "$3"

# Fix ownership since we're running under sudo
if [ "$USE_SUDO" == "no" ]; then
	chown "$SUDO_USER:$SUDO_USER" "$3"
fi

