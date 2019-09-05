#!/bin/bash

# Installation paths
DEFAULT_CONFIG_FILE=autorip.conf.default
CONFIG_PATH=/etc/autorip.conf
RULES_PATH=/etc/udev/rules.d/99-cd-processing.rules
INSTALL_PATH=/usr/local/sbin
CREDENTIALS_PATH=/root/.autorip
MUSIC_CONFIG_FILE=.abcde.conf

# Default configuration
get_config_var() {
    echo "$(awk -F '=' "/^$1/{print \$2}" $DEFAULT_CONFIG_FILE)"
}
OUTPUT_PATH=$(get_config_var OUTPUT_PATH)
MUSIC_CONFIG_PATH=$(get_config_var MUSIC_CONFIG_PATH)
MUSIC_DIR=$(get_config_var MUSIC_DIR)
REMOTE_PATH=""

# Guided installation
echo -n "Local path to store ripped media [$OUTPUT_PATH]: "
read NEW_OUTPUT_PATH
if [ ! -z "$NEW_OUTPUT_PATH" ]; then
    OUTPUT_PATH=$NEW_OUTPUT_PATH
fi
echo -n "Creating autorip storage path..."
if [ ! -d "$OUTPUT_PATH" ]; then
    mkdir -p "$OUTPUT_PATH"
fi
# Get rid of any trailing slash from mount path
CLEAN_OUTPUT_PATH=${OUTPUT_PATH%/}
echo "Done."

echo -n "Connect local path to SMB share? [Y/n] "
read RESPONSE
if [ -z "$RESPONSE" ] || [[ "$RESPONSE" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    echo -n "SMB share path (e.g. \"//server/share/path\"): "
    read REMOTE_PATH
    echo -n "SMB username: "
    read SMB_USERNAME
    echo -n "SMB password: "
    read -s SMB_PASSWORD
    echo ""

    echo -n "Creating autorip SMB credentials..."
    # Create and chmod first, before writing anything else. Just in case.
    > $CREDENTIALS_PATH
    chmod 600 $CREDENTIALS_PATH
    echo "username=$SMB_USERNAME" >> $CREDENTIALS_PATH
    echo "password=$SMB_PASSWORD" >> $CREDENTIALS_PATH
    echo "Done."

    echo -n "Adding remote mount to fstab..."
    # Just in case it already exists in fstab...
    # Unmount it quietly
    umount -q $CLEAN_OUTPUT_PATH
    # Determine the RegEx pattern to find the mount path
    # (with either trailing space, or trailing slash then space)
    PATTERN="\@$CLEAN_OUTPUT_PATH@d"
    # Remove line if it exists
    sed -i $PATTERN /etc/fstab
    # Add new fstab entry
    FSTAB_ENTRY="$REMOTE_PATH $CLEAN_OUTPUT_PATH cifs credentials=$CREDENTIALS_PATH 0 0"
    echo $FSTAB_ENTRY >> /etc/fstab

    # Mount fstab
    mount -a
    echo "Done."
fi

# Perform installation
install() {
    cp "$2" "$1"
    chmod +x "$1/$2"
    chown root:root "$1/$2"
}
echo -n "Installing script..."
install $INSTALL_PATH autorip.sh
install $INSTALL_PATH ripcd.sh
echo "Done."

echo -n "Updating udev rules..."
echo "SUBSYSTEM==\"block\" KERNEL==\"s[rg][0-9]*\", ACTION==\"change\", RUN+=\"$INSTALL_PATH/autorip.sh &\"" > "$RULES_PATH"
udevadm control --reload-rules
echo "Done."

echo -n "Writing configuration..."
cp $DEFAULT_CONFIG_FILE $CONFIG_PATH
sed -i "/OUTPUT_PATH/c\\OUTPUT_PATH=$CLEAN_OUTPUT_PATH" $CONFIG_PATH
sed -i "/REMOTE_PATH/c\\REMOTE_PATH=$REMOTE_PATH" $CONFIG_PATH
cp $MUSIC_CONFIG_FILE $MUSIC_CONFIG_PATH
sed -i "/OUTPUTDIR/c\\OUTPUTDIR=$CLEAN_OUTPUT_PATH/$MUSIC_DIR" $MUSIC_CONFIG_PATH
echo "Done."
