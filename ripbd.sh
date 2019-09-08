#!/bin/bash

# Set configuration path
CONFIG_PATH=/etc/autorip.conf

# Get configuration
get_config_var() {
    echo "$(awk -F '=' "/^$1/{print \$2}" $CONFIG_PATH)"
}
VIDEO_OUTPUT_PATH=$(get_config_var VIDEO_OUTPUT_PATH)
VIDEO_OUTPUT_PATH=${VIDEO_OUTPUT_PATH%/}
WORKING_PATH="$VIDEO_OUTPUT_PATH/${ID_FS_LABEL:0:8}"
WORKING_NAME="disc"
VIDEO_RIPPER_BIN=$(get_config_var VIDEO_RIPPER_BIN)
VIDEO_REJECT_RATIO=$(get_config_var VIDEO_RIPPER_BIN)
TRANSCODER_BIN=$(get_config_var TRANSCODER_BIN)
TRANSCODER_CONTAINER_FORMAT=$(get_config_var TRANSCODER_CONTAINER_FORMAT)
TRANSCODER_VIDEO_FORMAT=$(get_config_var TRANSCODER_VIDEO_FORMAT)
TRANSCODER_AUDIO_FORMAT=$(get_config_var TRANSCODER_AUDIO_FORMAT)

# Touch directory function (create if non-existent)
touch_dir() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
    fi
}

# Ensure the required media directories are available
touch_dir "$VIDEO_OUTPUT_PATH"
touch_dir "$WORKING_PATH"

# Get the disc working path
find /disc.rip/ -maxdepth 1 -type d -name "test*"
LAST_DISC_PATH=$(find "$WORKING_PATH" -maxdepth 1 -type d -name "$WORKING_NAME*" | tail -1)
LAST_DISC_NUM=$(grep -Eo '[0-9]+$' <<< $LAST_DISC_PATH)
DISC_NAME=$(printf '%s_%02d' "$WORKING_NAME" $(($LAST_DISC_NUM + 1)))
DISC_WORKING_PATH="$WORKING_PATH/$DISC_NAME"

# Execute rip
# $VIDEO_RIPPER_BIN mkv dev:$DEVNAME all $DISC_WORKING_PATH -r

# Find largest file size in directory and reject everything below the size
# factor limit (deletes random titles, special features, etc; leaves just
# the movie or episodes).
LARGEST_FILE=$(ls -Sa "$DISC_WORKING_PATH/*.mkv" | head -1)
LARGEST_FILE_SIZE=$(wc -c < "$LARGEST_FILE")
find "$DISC_WORKING_PATH" -maxdepth 1 -name "*.mkv" -size -"$(($LARGEST_FILE_SIZE / $VIDEO_REJECT_FACTOR))"c -delete

# Get next file number in WORKING_PATH
LAST_FILE=$(ls "$WORKING_PATH"/*.$TRANSCODER_CONTAINER_FORMAT | tail -1)
LAST_NAME=${LAST_FILE:0:-4}
LAST_NUM=$(grep -Eo '[0-9]+$' <<< $LAST_NAME)
CUR_NUM=$(($LAST_NUM + 1))

# Convert each of the MKV files pulled from the disc
for CUR_IN_PATH in "$DISC_WORKING_PATH"/* ; do
    if [ -d "$CUR_IN_PATH" ] || [ ! ${CUR_IN_PATH:-4} == ".mkv" ] ; then
        # Skip over directories and non-MKV files
        continue
    fi
    # CUR_IN_FILE=${CUR_IN_PATH##*/}
    # CUR_IN_NAME=${CUR_IN_FILE%.mkv}
    # CUR_IN_TITLE=${CUR_IN_NAME}
    CUR_OUT_FILE=$(printf '%s_%03d.%s' "$ID_FS_LABEL" "$CUR_NUM" "$TRANSCODER_CONTAINER_FORMAT")
    CUR_OUT_PATH="$WORKING_PATH"/"$CUR_OUT_FILE"
    CUR_NUM=$(($CUR_NUM + 1))
    $TRANSCODER_BIN -i $CUR_IN_PATH -c:v $TRANSCODER_VIDEO_FORMAT -c:a $TRANSCODER_AUDIO_FORMAT $CUR_OUT_PATH
    # $TRANSCODER_BIN -i $CUR_IN_PATH -c:v $TRANSCODER_VIDEO_FORMAT -c:a $TRANSCODER_AUDIO_FORMAT -c:s dvd_subtitle $CUR_OUT_PATH
done

# Clear the working disc directory
rm -f "$DISC_WORKING_PATH"/*
rmdir "$DISC_WORKING_PATH"

# Eject disc on completion
eject $DEVNAME
