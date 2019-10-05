#!/bin/bash

# if [ -z "$1" ] || [ ! -d "$1" ]; then
#     echo "Target directory required! (e.g. transcode.sh \"/path/to/mkvs\")"
#     exit 1
# fi

# Set configuration path
CONFIG_PATH=/etc/autorip.conf

# Get configuration
get_config_var() {
    echo "$(awk -F '=' "/^$1/{print \$2}" $CONFIG_PATH)"
}
VIDEO_WORKING_PATH=$(get_config_var VIDEO_WORKING_PATH)
# Protection to make sure the working path is NOT root directory
if [ "$VIDEO_WORKING_PATH" == "/" ] ; then
    exit 1
fi
VIDEO_WORKING_PATH=${VIDEO_WORKING_PATH%/}
TRANSCODER_BIN=$(get_config_var TRANSCODER_BIN)
TRANSCODER_CONTAINER_FORMAT=$(get_config_var TRANSCODER_CONTAINER_FORMAT)
TRANSCODER_VIDEO_FORMAT=$(get_config_var TRANSCODER_VIDEO_FORMAT)
TRANSCODER_AUDIO_FORMAT=$(get_config_var TRANSCODER_AUDIO_FORMAT)
TRANSCODER_AUDIO_CHANNELS=$(get_config_var TRANSCODER_AUDIO_CHANNELS)
DEFAULT_USER=$(get_config_var DEFAULT_USER)
DEFAULT_GROUP=$(get_config_var DEFAULT_GROUP)
DEFAULT_DIR_MODE=$(get_config_var DEFAULT_DIR_MODE)
DEFAULT_FILE_MODE=$(get_config_var DEFAULT_FILE_MODE)

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

# Loop through the directory, transcoding all available MKV files
while true; do

    # Find all the pending MKVs under the working directory (recursive)
    PENDING_MKVS=$(ls -1tr "$WORKING_PATH"/*/*.mkv)

    for CUR_IN_PATH in "$PENDING_MKVS" ; do
        # Determine the output path for the input path
        CUR_IN_FILE=$(basename "$CUR_IN_PATH")
        CUR_OUT_FILE=$(printf '%s.%s' "${CUR_IN_FILE:0:-4}" "$TRANSCODER_CONTAINER_FORMAT")
        CUR_OUT_PATH="$WORKING_PATH"/"$CUR_OUT_FILE"
        # Perform the transcode
        $TRANSCODER_BIN -i $CUR_IN_PATH -c:v $TRANSCODER_VIDEO_FORMAT -c:a $TRANSCODER_AUDIO_FORMAT -y $CUR_OUT_PATH
        # Set the permissions on the output
        chmod "$DEFAULT_FILE_MODE" "$CUR_OUT_PATH"
        own_target "$CUR_OUT_PATH"
        # Delete the input
        rm "$CUR_IN_PATH"
    done

    # Check if any more MKV files were added since finishing the last loop
    if [ "$(ls "$WORKING_PATH"/*/*.mkv | wc -l)" == 0 ]; then
        # We're done, break and finish
        break
    fi
    
done
