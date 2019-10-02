#!/bin/bash

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
WORKING_PATH="$VIDEO_WORKING_PATH"/"${ID_FS_LABEL:0:8}"
WORKING_NAME="disc"
ACTIVE_FILE="active"
VIDEO_RIPPER_BIN=$(get_config_var VIDEO_RIPPER_BIN)
VIDEO_REJECT_FACTOR=$(get_config_var VIDEO_REJECT_FACTOR)
TRANSCODER_BIN=$(get_config_var TRANSCODER_BIN)
TRANSCODER_CONTAINER_FORMAT=$(get_config_var TRANSCODER_CONTAINER_FORMAT)
TRANSCODER_VIDEO_FORMAT=$(get_config_var TRANSCODER_VIDEO_FORMAT)
TRANSCODER_AUDIO_FORMAT=$(get_config_var TRANSCODER_AUDIO_FORMAT)
TRANSCODER_AUDIO_CHANNELS=$(get_config_var TRANSCODER_AUDIO_CHANNELS)

# Touch directory function (create if non-existent)
touch_dir() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
    fi
}

# Get the disc working path
LAST_DISC_PATH=$(find "$WORKING_PATH" -maxdepth 1 -type d -name "$WORKING_NAME*" | tail -1)
LAST_DISC_NUM=$(grep -Eo '[0-9]+$' <<< $LAST_DISC_PATH)
DISC_NAME=$(printf '%s_%02d' "$WORKING_NAME" $(($LAST_DISC_NUM + 1)))
DISC_WORKING_PATH="$WORKING_PATH/$DISC_NAME"

# Ensure the required media directories are available
touch_dir "$VIDEO_WORKING_PATH"
touch_dir "$WORKING_PATH"
touch_dir "$DISC_WORKING_PATH"

# Set the active rip
ACTIVE_FILE_PATH="$VIDEO_WORKING_PATH"/"$ACTIVE_FILE"
> "$ACTIVE_FILE_PATH"
echo $ID_FS_LABEL >> "$ACTIVE_FILE_PATH"
echo "$WORKING_PATH" >> "$ACTIVE_FILE_PATH"

# Execute rip
# "$VIDEO_RIPPER_BIN" mkv dev:"$DEVNAME" all "$DISC_WORKING_PATH" -r

# Find largest file size in directory and reject everything below the size
# factor limit (deletes random titles, special features, etc; leaves just
# the movie or episodes).
LARGEST_FILE=$(ls -Sa "$DISC_WORKING_PATH"/*.mkv | head -1)
LARGEST_FILE_SIZE=$(wc -c < "$LARGEST_FILE")
find "$DISC_WORKING_PATH" -maxdepth 1 -name "*.mkv" -size -"$(($LARGEST_FILE_SIZE / $VIDEO_REJECT_FACTOR))"c -delete

# Get next file number in WORKING_PATH
LAST_FILE=$(find "$WORKING_PATH" -maxdepth 1 -type f -name "*.$TRANSCODER_CONTAINER_FORMAT" | tail -1)
if [ -f "$LAST_FILE" ] ; then
    LAST_NAME=${LAST_FILE:0:-4}
    LAST_NUM=$(grep -Eo '[0-9]+$' <<< $LAST_NAME)
    CUR_NUM=$(($LAST_NUM + 1))
else
    CUR_NUM=1
fi

# Convert each of the MKV files pulled from the disc
for CUR_IN_PATH in "$DISC_WORKING_PATH"/* ; do
    if [ -d "$CUR_IN_PATH" ] || [ ${CUR_IN_PATH: -4} != ".mkv" ] ; then
        # Skip over directories and non-MKV files
        continue
    fi
    # CUR_IN_FILE=${CUR_IN_PATH##*/}
    # CUR_IN_NAME=${CUR_IN_FILE%.mkv}
    # CUR_IN_TITLE=${CUR_IN_NAME}
    CUR_OUT_FILE=$(printf '%s_%03d.%s' "$ID_FS_LABEL" "$CUR_NUM" "$TRANSCODER_CONTAINER_FORMAT")
    CUR_OUT_PATH="$WORKING_PATH"/"$CUR_OUT_FILE"
    CUR_NUM=$(($CUR_NUM + 1))
    $TRANSCODER_BIN -i $CUR_IN_PATH -c:v $TRANSCODER_VIDEO_FORMAT -c:a $TRANSCODER_AUDIO_FORMAT -ac $TRANSCODER_AUDIO_CHANNELS $CUR_OUT_PATH
done

# Clear the working disc directory
rm -f "$DISC_WORKING_PATH"/*
rmdir "$DISC_WORKING_PATH"

# Eject disc on completion
eject $DEVNAME
