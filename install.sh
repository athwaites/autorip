#!/bin/bash

# Installation paths
DEFAULT_CONFIG_FILE=autorip.conf.default
CONFIG_PATH=/etc/autorip.conf
RULES_PATH=/etc/udev/rules.d/99-cd-processing.rules
INSTALL_PATH=/usr/local/sbin
SCRIPT_FILE=autorip.sh
SCRIPT_PATH=$INSTALL_PATH/$SCRIPT_FILE
CREDENTIALS_PATH=/root/.autorip

# Default configuration
OUTPUT_PATH=$(awk -F '[\s=]+' '/^OUTPUT_PATH/{print $2}' $DEFAULT_CONFIG_FILE)
REMOTE_PATH=""

# Guided installation
echo -n "Local path to store ripped media [$OUTPUT_PATH]: "
read NEW_OUTPUT_PATH
if [ -z "$NEW_OUTPUT_PATH" ]; then
    OUTPUT_PATH=$NEW_OUTPUT_PATH
fi
echo -n "Creating autorip storage path..."
if [ ! -d "$OUTPUT_PATH" ]; then
    mkdir -p "$OUTPUT_PATH"
fi
echo "Done."

echo -n "Connect local path to SMB share? [Y/n]"
read RESPONSE
if [[ "$RESPONSE" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    echo "SMB share path (e.g. $REMOTE_PATH):"
    read REMOTE_PATH
    echo -n "SMB username: "
    read SMB_USERNAME
    echo -n "SMB password: "
    read -s SMB_PASSWORD

    echo -n "Creating autorip SMB credentials..."
    # Create and chmod first, before writing anything else. Just in case.
    > $CREDENTIALS_PATH
    chmod 600 $CREDENTIALS_PATH
    echo "username=$SMB_USERNAME" >> $CREDENTIALS_PATH
    echo "password=$SMB_PASSWORD" >> $CREDENTIALS_PATH
    echo "Done."
fi

# Perform installation
echo -n "Installing script..."
cp "$SCRIPT_FILE" "$INSTALL_PATH"
chmod +x "$SCRIPT_PATH"
chown root:root "$SCRIPT_PATH"
echo "Done."

echo -n "Updating udev rules..."
echo "SUBSYSTEM==\"block\" KERNEL==\"s[rg][0-9]*\", ACTION==\"change\", RUN+=\"$SCRIPT_PATH &\"" > "$RULES_PATH"
udevadm control --reload-rules
echo "Done."

echo -n "Writing configuration..."
cp $DEFAULT_CONFIG_FILE $CONFIG_PATH
sed -i "s/OUTPUT_PATH.*/OUTPUT_PATH = $OUTPUT_PATH/" $CONFIG_PATH
sed -i "s/REMOTE_PATH.*/REMOTE_PATH = $REMOTE_PATH/" $CONFIG_PATH
echo "Done."
