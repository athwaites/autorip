#!/bin/bash

# Set configuration path
CONFIG_PATH=/etc/autorip.conf

# Get configuration
get_config_var() {
    echo "$(awk -F '=' "/^$1/{print \$2}" "$CONFIG_PATH")"
}
OUTPUT_PATH=$(get_config_var OUTPUT_PATH)
OUTPUT_PATH=${OUTPUT_PATH%/}
MUSIC_PATH="$OUTPUT_PATH/$(get_config_var MUSIC_DIR)"
MOVIES_PATH="$OUTPUT_PATH/$(get_config_var MOVIES_DIR)"
TELEVISION_PATH="$OUTPUT_PATH/$(get_config_var TELEVISION_DIR)"
MUSIC_CONFIG_PATH=$(get_config_var MUSIC_CONFIG_PATH)
DEFAULT_USER=$(get_config_var DEFAULT_USER)
DEFAULT_GROUP=$(get_config_var DEFAULT_GROUP)
DEFAULT_DIR_MODE=$(get_config_var DEFAULT_DIR_MODE)
DEFAULT_FILE_MODE=$(get_config_var DEFAULT_FILE_MODE)

# Touch directory function (create if non-existent)
touch_dir() {
    if [ ! -d "$1" ]; then
        if [ "$DEFAULT_USER" ]; then
            if [ "$DEFAULT_GROUP" ]; then
                install -d -m "$DEFAULT_DIR_MODE" -o "$DEFAULT_USER" -g "$DEFAULT_GROUP" "$1"
            else
                install -d -m "$DEFAULT_DIR_MODE" -o "$DEFAULT_USER" "$1"
            fi
        elif [ "$DEFAULT_GROUP" ]; then
            install -d -m "$DEFAULT_DIR_MODE" -g "$DEFAULT_GROUP" "$1"
        else
            mkdir -p -m "$DEFAULT_DIR_MODE" "$1"
        fi
    fi
}

# Set target ownership function
own_target() {
    if [ "$DEFAULT_USER" ]; then
        if [ "$DEFAULT_GROUP" ]; then
            chown "$DEFAULT_USER:$DEFAULT_GROUP" "$1"
        else
            chown "$DEFAULT_USER" "$1"
        fi
    elif [ "$DEFAULT_GROUP" ]; then
        chgrp "$DEFAULT_GROUP" "$1"
    fi
}

# Check for remote mount and mount now if unavailable
REMOTE_PATH=$(get_config_var REMOTE_PATH)
if [ ! -z "$REMOTE_PATH" ]; then
    if [ -z "$(mount | grep \"$REMOTE_PATH\")" ]; then
        SMB_GID=$(get_config_var SMB_GID)
        if [ -z "$SMB_GID" ]; then
            SMB_GID_OPT=""
        else
            SMB_GID_OPT=",gid=$SMB_GID"
        fi
        mount.cifs "$REMOTE_PATH" "$OUTPUT_PATH" -o rw,credentials=$(get_config_var SMB_CREDENTIALS),file_mode=0775,dir_mode=0775$SMB_GID_OPT
    fi
fi

# Ensure the required media directories are available
touch_dir "$MUSIC_PATH"
touch_dir "$MOVIES_PATH"
touch_dir "$TELEVISION_PATH"

# Determine media type and call appropriate function
if [ "$ID_CDROM_MEDIA_CD" = 1 ]; then
    echo /usr/local/sbin/ripcd.sh | at now
elif [ "$ID_CDROM_MEDIA_DVD" = 1 ] || [ "$ID_CDROM_MEDIA_BD" = 1 ]; then
    echo /usr/local/sbin/ripdvd.sh | at now 
fi
