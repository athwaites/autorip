#!/bin/bash

# Set configuration path
CONFIG_PATH=/etc/autorip.conf

# Get configuration
get_config_var() {
    echo "$(awk -F '=' "/^$1/{print \$2}" $CONFIG_PATH)"
}
WORKING_PATH=$(get_config_var VIDEO_TRANSCODING_PATH)
# Protection to make sure the working path is NOT root directory
if [ "$WORKING_PATH" == "/" ] || [ -z "$WORKING_PATH" ] ; then
    exit 1
fi
WORKING_PATH=${WORKING_PATH%/}
OUTPUT_PATH=$(get_config_var VIDEO_COMPLETE_PATH)
# Protection to make sure the output path is NOT root directory
if [ "$OUTPUT_PATH" == "/" ] ; then
    exit 1
fi
OUTPUT_PATH=${OUTPUT_PATH%/}
TRANSCODER_CONTAINER_FORMAT=$(get_config_var TRANSCODER_CONTAINER_FORMAT)
TRANSCODER_VIDEO_FORMAT=$(get_config_var TRANSCODER_VIDEO_FORMAT)
TRANSCODER_VIDEO_PRESET=$(get_config_var TRANSCODER_VIDEO_PRESET)
TRANSCODER_VIDEO_CRF=$(get_config_var TRANSCODER_VIDEO_CRF)
TRANSCODER_AUDIO_RATE=$(get_config_var TRANSCODER_AUDIO_RATE)
TRANSCODER_STEREO_FORMAT=$(get_config_var TRANSCODER_STEREO_FORMAT)
TRANSCODER_SURROUND_FORMAT=$(get_config_var TRANSCODER_SURROUND_FORMAT)
TRANSCODER_HDSURROUND_FORMAT=$(get_config_var TRANSCODER_HDSURROUND_FORMAT)
TRANSCODER_STEREO_BITRATE=$(get_config_var TRANSCODER_STEREO_BITRATE)
TRANSCODER_SURROUND_BITRATE=$(get_config_var TRANSCODER_SURROUND_BITRATE)
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

# Get codec information
# $1: path of file to probe
# $2: selected stream (e.g. v:0 for first video stream; a:0 for first audio stream)
# $3: setting name (e.g. codec_name)
get_stream_setting() {
    SETTING_LINE=$(ffprobe -v error -select_streams "$2" -show_entries stream="$3" -of csv=p=0 "$1")
    echo "${SETTING_LINE#*=}"
}

# Perform the correct transcode routine
# $1: input file path
# $2: output file path
do_transcode() {
    NUM_CHANNELS=$(get_stream_setting "$1" a:0 channels)
    ALT_NUM_CHANNELS=$(get_stream_setting "$1" a:1 channels)
    INPUT_CODEC_NAME=$(get_stream_setting "$1" a:0 codec_name)
    INPUT_CODEC_PROFILE=$(get_stream_setting "$1" a:0 profile)
    SUBTITLES=$(get_stream_setting "$1" s:0 codec_name)
    HD_COPY=0

    # Determine the output format and bitrate based on the input audio stream
    if [ "$NUM_CHANNELS" -eq 2 ]; then
        # Stereo
        OUTPUT_FORMAT=$TRANSCODER_STEREO_FORMAT
        OUTPUT_BITRATE=$TRANSCODER_STEREO_BITRATE
    else
        # Normal Surround
        OUTPUT_FORMAT=$TRANSCODER_SURROUND_FORMAT
        OUTPUT_BITRATE=$TRANSCODER_SURROUND_BITRATE
    fi
    
    # Check for HD audio
    if [ "$INPUT_CODEC_NAME" == "truehd" ] || [ "$INPUT_CODEC_PROFILE" == *"HD"* ] || [ "$NUM_CHANNELS" -eq 8 ]; then
        HD_COPY=1
    fi

    # Execute the transcode
    if [ "$SUBTITLES" ]; then
        # With subtitles
        if [ "$HD_COPY" ]; then
            # With HD copy
            ffmpeg -i "$1" \
            -map 0:v:0 -c:v:0 "$TRANSCODER_VIDEO_FORMAT" -crf "$TRANSCODER_VIDEO_CRF" -preset "$TRANSCODER_VIDEO_PRESET" -max_muxing_queue_size 9999 \
            -map 0:a:0 -c:a:0 copy \
            -map 0:a:1 -c:a:1 "$OUTPUT_FORMAT" -ar "$TRANSCODER_AUDIO_RATE" -ab "$OUTPUT_BITRATE" -ac "$ALT_NUM_CHANNELS" \
            -map 0:s:0 -c:s:0 copy \
            -y "$2"
        else
            # Without HD copy
            ffmpeg -i "$1" \
            -map 0:v:0 -c:v:0 "$TRANSCODER_VIDEO_FORMAT" -crf "$TRANSCODER_VIDEO_CRF" -preset "$TRANSCODER_VIDEO_PRESET" -max_muxing_queue_size 9999 \
            -map 0:a:0 -c:a:0 "$OUTPUT_FORMAT" -ar "$TRANSCODER_AUDIO_RATE" -ab "$OUTPUT_BITRATE" -ac "$NUM_CHANNELS" \
            -map 0:s:0 -c:s:0 copy \
            -y "$2"
        fi
    else
        # Without subtitles
        if [ "$HD_COPY" ]; then
            # With HD copy
            ffmpeg -i "$1" \
            -map 0:v:0 -c:v:0 "$TRANSCODER_VIDEO_FORMAT" -crf "$TRANSCODER_VIDEO_CRF" -preset "$TRANSCODER_VIDEO_PRESET" -max_muxing_queue_size 9999 \
            -map 0:a:0 -c:a:0 copy \
            -map 0:a:1 -c:a:1 "$OUTPUT_FORMAT" -ar "$TRANSCODER_AUDIO_RATE" -ab "$OUTPUT_BITRATE" -ac "$ALT_NUM_CHANNELS" \
            -y "$2"
        else
            # Without HD copy
            ffmpeg -i "$1" \
            -map 0:v:0 -c:v:0 "$TRANSCODER_VIDEO_FORMAT" -crf "$TRANSCODER_VIDEO_CRF" -preset "$TRANSCODER_VIDEO_PRESET" -max_muxing_queue_size 9999 \
            -map 0:a:0 -c:a:0 "$OUTPUT_FORMAT" -ar "$TRANSCODER_AUDIO_RATE" -ab "$OUTPUT_BITRATE" -ac "$NUM_CHANNELS" \
            -y "$2"
        fi
    fi
}

# Ensure the required directories are available
touch_dir "$OUTPUT_PATH"

# Loop through the directory, transcoding all available MKV files
while true; do

    # Find all the pending MKVs under the working directory (recursive)
    IFS=$'\n'   # Set the for-loop separator to newline only
    for CUR_IN_PATH in $(find "$WORKING_PATH" -type f -name "*.mkv" -printf "%T@ %p\n" | sort -n | cut -d ' ' -f 2-); do
        # Determine the output path for the input path
        CUR_IN_FILE=$(basename "$CUR_IN_PATH")
        CUR_IN_DIR=$(dirname "$CUR_IN_PATH")
        # Replace the working path section of the current output directory with the output directory path
        CUR_OUT_DIR="$OUTPUT_PATH""${CUR_IN_DIR:${#WORKING_PATH}:${#CUR_IN_DIR}}"
        CUR_TC_FILE=$(printf '%s.%s' "${CUR_IN_FILE:0:-4}_TC" "$TRANSCODER_CONTAINER_FORMAT")
        CUR_OUT_FILE=$(printf '%s.%s' "${CUR_IN_FILE:0:-4}" "$TRANSCODER_CONTAINER_FORMAT")
        CUR_TC_PATH="$CUR_IN_DIR"/"$CUR_TC_FILE"
        CUR_OUT_PATH="$CUR_OUT_DIR"/"$CUR_OUT_FILE"
        # Perform the transcode
        do_transcode "$CUR_IN_PATH" "$CUR_TC_PATH"
        # Make sure the output location exists
        touch_dir "$CUR_OUT_DIR"
        # Move the result on completion
        mv "$CUR_TC_PATH" "$CUR_OUT_PATH"
        # Set the permissions on the output
        chmod "$DEFAULT_FILE_MODE" "$CUR_OUT_PATH"
        own_target "$CUR_OUT_PATH"
        # Delete the input
        rm "$CUR_IN_PATH"
        rmdir "$CUR_IN_DIR"
    done

    # Check if any more MKV files were added since finishing the last loop
    if [ "$(find "$WORKING_PATH" -type f -name "*.mkv" | wc -l)" -eq 0 ]; then
        # We're done, break and finish
        break
    fi
    
done
