#!/bin/bash

# Set configuration path
CONFIG_PATH=/etc/autorip.conf

# Get configuration
get_config_var() {
    echo "$(awk -F '=' "/^$1/{print \$2}" $CONFIG_PATH)"
}
OUTPUT_PATH=$(get_config_var OUTPUT_PATH)
CLEAN_OUTPUT_PATH=${OUTPUT_PATH%/}
MUSIC_PATH=$CLEAN_OUTPUT_PATH/$(get_config_var MUSIC_DIR)
MOVIES_PATH=$CLEAN_OUTPUT_PATH/$(get_config_var MOVIES_DIR)
TELEVISION_PATH=$CLEAN_OUTPUT_PATH/$(get_config_var TELEVISION_DIR)
MUSIC_CONFIG_PATH=$(get_config_var MUSIC_CONFIG_PATH)

# Touch directory function (create if non-existent)
touch_dir() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
    fi
}

# Check for remote mount and mount now if unavailable
REMOTE_PATH=$(get_config_var REMOTE_PATH)
if [ ! -z "$REMOTE_PATH" ]; then
    if [ -z "$(mount | grep $REMOTE_PATH)" ]; then
        $SMB_GID=$(get_config_var SMB_GID)
        if [ -z $SMB_GID ]; then
            $SMB_GID_OPT=""
        else
            $SMB_GID_OPT=",gid=$SMB_GID"
        fi
        mount.cifs $REMOTE_PATH $CLEAN_OUTPUT_PATH -o rw,credentials=$(get_config_var SMB_CREDENTIALS),file_mode=0775,dir_mode=0775$SMB_GID_OPT
    fi
fi

# Ensure the required media directories are available
touch_dir $MUSIC_PATH
touch_dir $MOVIES_PATH
touch_dir $TELEVISION_PATH

# Determine media type and call appropriate function
if [ "$ID_CDROM_MEDIA_CD" = 1 ]; then
    echo /usr/local/sbin/ripcd.sh | at now
elif [ "$ID_CDROM_MEDIA_DVD" = 1 ]; then
    echo
    #echo /usr/local/sbin/ripdvd.sh | at now
elif [ "$ID_CDROM_MEDIA_BD" = 1 ]; then
    echo
    #echo /usr/local/sbin/ripbd.sh | at now
fi
