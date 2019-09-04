#!/bin/bash

# Set configuration path
CONFIG_PATH=/etc/autorip.conf

# Get configuration
get_config_var() {
    echo "$(awk -F '[\s=]+' "/^$1/{print \$2}" $CONFIG_PATH)"
}
OUTPUT_PATH=$(get_var OUTPUT_PATH)
REMOTE_PATH=$(get_var REMOTE_PATH)
CREDENTIALS_PATH=$(get_var CREDENTIALS_PATH)
MUSIC_PATH=$OUTPUT_PATH/$(get_var MUSIC_DIR)
MOVIES_PATH=$OUTPUT_PATH/$(get_var MOVIES_DIR)
TELEVISION_PATH=$OUTPUT_PATH/$(get_var TELEVISION_DIR)

# Touch directory function (create if non-existent)
touch_dir() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
    fi
}

# Rip CD function
rip_cd() {
    
}

# Rip DVD function
rip_dvd() {

}

# Rip Blu-Ray function
rip_bd() {

}

# Check for remote mount and mount now if unavailable
if [ ! -z "$REMOTE_PATH" ]; then
    if [ -z "$(mount | grep '$REMOTE_PATH')" ]; then
        mount.cifs $REMOTE_PATH $OUTPUT_PATH -o rw,credentials=$CREDENTIALS_PATH
    fi
fi

# Ensure the required media directories are available
touch_dir $MUSIC_PATH
touch_dir $MOVIES_PATH
touch_dir $TELEVISION_PATH

# Determine media type and call appropriate function
if [ "$ID_CDROM_MEDIA_CD" = 1 ]; then
    rip_cd
elif [ "$ID_CDROM_MEDIA_DVD" = 1 ]; then
    rip_dvd
elif [ "$ID_CDROM_MEDIA_BD" = 1 ]; then
    rip_bd
fi
