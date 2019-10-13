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
WORKING_PATH=$(get_config_var VIDEO_WORKING_PATH)
# Protection to make sure the working path is NOT root directory
if [ "$WORKING_PATH" == "/" ] || [ -z "$WORKING_PATH" ] ; then
    exit 1
fi
WORKING_PATH=${WORKING_PATH%/}
TRANSCODER_BIN=$(get_config_var TRANSCODER_BIN)
TRANSCODER_BIN_PROBE=$(get_config_var TRANSCODER_BIN_PROBE)
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
    SETTING_LINE=$("$TRANSCODER_BIN_PROBE" -v error -select_streams "$2" -show_entries stream="$3" "$1" | sed -n 2p)
    echo "${SETTING_LINE#*=}"
}

# Get video options for transcode command
# $1: input file path
get_video_options() {
    echo -map 0:v:0 -c:v:0 "$TRANSCODER_VIDEO_FORMAT" -crf "$TRANSCODER_VIDEO_CRF" -preset "$TRANSCODER_VIDEO_PRESET" -max_muxing_queue_size 9999
}

# Get audio options for transcode command
# $1: input file path
get_audio_options() {
    
    NUM_CHANNELS=$(get_stream_setting "$1" a:0 channels)
    INPUT_CODEC_NAME=$(get_stream_setting "$1" a:0 codec_name)
    INPUT_CODEC_PROFILE=$(get_stream_setting "$1" a:0 profile)

    # Determine the output format and bitrate based on the input audio stream
    if [ "$NUM_CHANNELS" -eq 2 ]; then
        # Stereo
        OUTPUT_FORMAT=$TRANSCODER_STEREO_FORMAT
        OUTPUT_BITRATE=$TRANSCODER_STEREO_BITRATE
    elif [ "$INPUT_CODEC_NAME" == "truehd" ] || [ "$INPUT_CODEC_PROFILE" == *"HD"* ]; then
        # HD Surround
        OUTPUT_FORMAT=$TRANSCODER_HDSURROUND_FORMAT
        OUTPUT_BITRATE=$TRANSCODER_SURROUND_BITRATE
    else
        # Normal Surround
        OUTPUT_FORMAT=$TRANSCODER_SURROUND_FORMAT
        OUTPUT_BITRATE=$TRANSCODER_SURROUND_BITRATE
    fi
    
    # Trim the number of channels to the codec limit
    if [ "$NUM_CHANNELS" -eq 8 ]; then
        NUM_CHANNELS=6
    fi

    # Return the audio option string
    echo -map 0:a:0 -c:a:0 "$OUTPUT_FORMAT" -ar "$TRANSCODER_AUDIO_RATE" -ab "$OUTPUT_BITRATE" -ac "$NUM_CHANNELS"
}

# Get transcode command
# $1: input file path
# $2: output file path
get_transcode_command() {
    echo "$TRANSCODER_BIN" -i "$1" $(get_video_options "$1") $(get_audio_options "$1") -y "$2"
}

# Loop through the directory, transcoding all available MKV files
while true; do

    # Find all the pending MKVs under the working directory (recursive)
    IFS=$'\n'   # Set the for-loop separator to newline only
    for CUR_IN_PATH in $(find "$WORKING_PATH" -type f -name "*.mkv" -printf "%T@ %p\n" | sort -n | cut -d ' ' -f 2-); do
        # Determine the output path for the input path
        CUR_IN_FILE=$(basename "$CUR_IN_PATH")
        CUR_OUT_DIR=$(dirname "$CUR_IN_PATH")
        CUR_OUT_FILE=$(printf '%s.%s' "${CUR_IN_FILE:0:-4}" "$TRANSCODER_CONTAINER_FORMAT")
        CUR_OUT_PATH="$CUR_OUT_DIR"/"$CUR_OUT_FILE"
        # Perform the transcode
        echo $(get_transcode_command "$CUR_IN_PATH" "$CUR_OUT_PATH")
        # eval $(get_transcode_command "$CUR_IN_PATH" "$CUR_OUT_PATH")
        # # Set the permissions on the output
        # chmod "$DEFAULT_FILE_MODE" "$CUR_OUT_PATH"
        # own_target "$CUR_OUT_PATH"
        # # Delete the input
        # rm "$CUR_IN_PATH"
    done

    # # Check if any more MKV files were added since finishing the last loop
    # if [ "$(ls "$WORKING_PATH"/*/*.mkv | wc -l)" == 0 ]; then
    #     # We're done, break and finish
    #     break
    # fi
    
done
