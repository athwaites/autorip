#!/bin/bash

# Installation paths
RULES_PATH=/etc/udev/rules.d/99-cd-processing.rules
INSTALL_PATH=/usr/local/sbin
SCRIPT_NAME=autorip.sh
SCRIPT_PATH= $INSTALL_PATH/$SCRIPT_NAME

if test -e "$RULES_PATH"; then
    echo "Updating udev rules..."
    rm "$RULES_PATH"
else
    echo "Adding udev rules..."
fi
echo "SUBSYSTEM==\"block\" KERNEL==\"s[rg][0-9]*\", ACTION==\"change\", RUN+=\"$SCRIPT_PATH &\"" >> "$RULES_PATH"

echo "Installing script..."
cp "$SCRIPT_NAME" "$INSTALL_PATH"
chmod +x "$SCRIPT_PATH"
chown root:root "$SCRIPT_PATH"

echo "Reloading udev rules..."
udevadm control --reload-rules

echo "Done!"
