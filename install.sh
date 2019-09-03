#!/bin/bash

# Installation paths
CONFIG_PATH=/etc/autorip.conf
RULES_PATH=/etc/udev/rules.d/99-cd-processing.rules
INSTALL_PATH=/usr/local/sbin
SCRIPT_NAME=autorip.sh
SCRIPT_PATH= $INSTALL_PATH/$SCRIPT_NAME
MOUNT_PATH=/mnt/autorip
CREDENTIALS_PATH=/root/.autorip

# Get installation settings
echo -n "Remote SMB path to store ripped media: "
read REMOTE_PATH
echo -n "Local path to mount remote: "
read MOUNT_PATH
echo -n "SMB username: "
read SMB_USERNAME
echo -n "SMB password: "
read -s SMB_PASSWORD

# Perform installation
echo "Installing script..."
cp "$SCRIPT_NAME" "$INSTALL_PATH"
chmod +x "$SCRIPT_PATH"
chown root:root "$SCRIPT_PATH"

if test -e "$RULES_PATH"; then
    echo "Updating udev rules..."
    rm "$RULES_PATH"
else
    echo "Adding udev rules..."
fi
echo "SUBSYSTEM==\"block\" KERNEL==\"s[rg][0-9]*\", ACTION==\"change\", RUN+=\"$SCRIPT_PATH &\"" >> "$RULES_PATH"

echo "Reloading udev rules..."
udevadm control --reload-rules

echo "Creating autorip SMB credentials..."
> $CREDENTIALS_PATH
chmod 600 $CREDENTIALS_PATH
echo "username=$SMB_USERNAME" >> $CREDENTIALS_PATH
echo "password=$SMB_PASSWORD" >> $CREDENTIALS_PATH

echo "Creating autorip mount point..."
if [ ! -d "$MOUNT_PATH" ]; then
    mkdir -p "$MOUNT_PATH"
fi

echo "Adding remote mount to fstab..."
# Get rid of any trailing slash from mount path
CLEAN_MOUNT_PATH=${MOUNT_PATH%/}
# Just in case it already exists in fstab...
# Unmount it quietly
umount -q $CLEAN_MOUNT_PATH
# Determine the RegEx pattern to find the mount path
# (with either trailing space, or trailing slash then space)
PATTERN="\@\s$CLEAN_MOUNT_PATH\(\s\|/\s\)@d"
# Remove line if it exists
sed -i $PATTERN /etc/fstab

# Add new fstab entry
FSTAB_ENTRY="$REMOTE_PATH $CLEAN_MOUNT_PATH cifs credentials=$CREDENTIALS_PATH,iocharset=utf8,sec=ntlm 0 0"
# Mount fstab
mount -a

# Build config
# TODO
# N.B. If building a config, maybe better not to mess with fstab and to just
# mount from configuration as required?

echo "Done!"
