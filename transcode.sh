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
TRANSCODER_VIDEO_COLOUR=$(get_config_var TRANSCODER_VIDEO_COLOUR)
TRANSCODER_AUDIO_RATE=$(get_config_var TRANSCODER_AUDIO_RATE)
TRANSCODER_LANGUAGE=$(get_config_var TRANSCODER_LANGUAGE)
TRANSCODER_STEREO_FORMAT=$(get_config_var TRANSCODER_STEREO_FORMAT)
TRANSCODER_SURROUND_FORMAT=$(get_config_var TRANSCODER_SURROUND_FORMAT)
TRANSCODER_HDSURROUND_FORMAT=$(get_config_var TRANSCODER_HDSURROUND_FORMAT)
TRANSCODER_STEREO_BITRATE=$(get_config_var TRANSCODER_STEREO_BITRATE)
TRANSCODER_SURROUND_BITRATE=$(get_config_var TRANSCODER_SURROUND_BITRATE)
TRANSCODER_DOWNSCALE_HDR=$(get_config_var TRANSCODER_DOWNSCALE_HDR)
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

# Get language index (returns stream index of first "hit")
# $1: path of file to probe
# $2: selected stream type (e.g. a for audio streams; s for subtitle streams)
# $3: language code (e.g. "eng" for English)
get_language_index() {
    STREAM_INDEX=$(ffprobe -v error -show_entries stream_tags=language -select_streams "$2" -of compact=p=0:nk=1 "$1" | grep -n "$3" | head -1 | cut -d ":" -f 1)
    if [ "$STREAM_INDEX" ]; then
        # Correct for 0-indexed streams in ffmpeg against 1-indexed lines for grep
        STREAM_INDEX=$((10#$STREAM_INDEX - 1))
    fi
    echo "$STREAM_INDEX"
}

# Perform the correct transcode routine
# $1: input file path
# $2: output file path
do_transcode() {
    NUM_CHANNELS=$(get_stream_setting "$1" a:0 channels)
    ALT_NUM_CHANNELS=$(get_stream_setting "$1" a:1 channels)
    SUBTITLES=$(get_stream_setting "$1" s:0 codec_name)
    PIXEL_FORMAT=$(get_stream_setting "$1" v:0 pix_fmt)
    AUDIO_LANGUAGE_INDEX=$(get_language_index "$1" a "$TRANSCODER_LANGUAGE")
    SUBTITLE_LANGUAGE_INDEX=$(get_language_index "$1" s "$TRANSCODER_LANGUAGE")

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

    # Determine the audio stream map
    if [ -z "$AUDIO_LANGUAGE_INDEX" ]; then
        # If there is no audio for the requested language, take the first track
        AUDIO_LANGUAGE_INDEX=0
    fi

    # Determine the subtitle stream map
    if [ -z "$SUBTITLE_LANGUAGE_INDEX" ]; then
        # If there is no subtitle for the requested language, don't bother with subtitles at all
        SUBTITLES=""
    fi

    # Determine the HDR state
    if [ "$PIXEL_FORMAT" == "yuv420p10le" ] && [ "$TRANSCODER_DOWNSCALE_HDR" == "1" ]; then
        #TONEMAP_OPTION="zscale=transfer=linear,tonemap=hable,zscale=transfer=bt709"
        TONEMAP_OPTION="zscale=tin=smpte2084:min=bt2020nc:pin=bt2020:rin=tv:t=smpte2084:m=bt2020nc:p=bt2020:r=tv,zscale=t=linear,tonemap=tonemap=hable,zscale=t=bt709,format=yuv420p"
    else
        TONEMAP_OPTION="format=yuv420p"
    fi

    # Execute the transcode
    if [ "$SUBTITLES" ]; then
        # With subtitles
        if [ "$NUM_CHANNELS" -gt 6 ]; then
            # With >6-Channel copy
            ffmpeg -i "$1" \
            -map 0:v:0 \
                -c:v:0 "$TRANSCODER_VIDEO_FORMAT" \
                -crf "$TRANSCODER_VIDEO_CRF" \
                -preset "$TRANSCODER_VIDEO_PRESET" \
                -vf "$TONEMAP_OPTION" \
                -max_muxing_queue_size 9999 \
            -map 0:a:"$AUDIO_LANGUAGE_INDEX" \
                -c:a:0 copy \
            -map 0:s:"$SUBTITLE_LANGUAGE_INDEX" \
                -c:s:0 copy \
            -y "$2"
        else
            # With <=6-Channel copy
            ffmpeg -i "$1" \
            -map 0:v:0 \
                -c:v:0 "$TRANSCODER_VIDEO_FORMAT" \
                -crf "$TRANSCODER_VIDEO_CRF" \
                -preset "$TRANSCODER_VIDEO_PRESET" \
                -vf "$TONEMAP_OPTION" \
                -max_muxing_queue_size 9999 \
            -map 0:a:"$AUDIO_LANGUAGE_INDEX" \
                -c:a:0 "$OUTPUT_FORMAT" \
                -ar "$TRANSCODER_AUDIO_RATE" \
                -ab "$OUTPUT_BITRATE" \
                -ac "$NUM_CHANNELS" \
            -map 0:s:"$SUBTITLE_LANGUAGE_INDEX" \
                -c:s:0 copy \
            -y "$2"
        fi
    else
        # Without subtitles
        if [ "$NUM_CHANNELS" -gt 6 ]; then
            # With >6-Channel copy
            ffmpeg -i "$1" \
            -map 0:v:0 \
                -c:v:0 "$TRANSCODER_VIDEO_FORMAT" \
                -crf "$TRANSCODER_VIDEO_CRF" \
                -preset "$TRANSCODER_VIDEO_PRESET" \
                -vf "$TONEMAP_OPTION" \
                -max_muxing_queue_size 9999 \
            -map 0:a:"$AUDIO_LANGUAGE_INDEX" \
                -c:a:0 copy \
            -y "$2"
        else
            # With <=6-Channel copy
            ffmpeg -i "$1" \
            -map 0:v:0 \
                -c:v:0 "$TRANSCODER_VIDEO_FORMAT" \
                -crf "$TRANSCODER_VIDEO_CRF" \
                -preset "$TRANSCODER_VIDEO_PRESET" \
                -vf "$TONEMAP_OPTION" \
                -max_muxing_queue_size 9999 \
            -map 0:a:"$AUDIO_LANGUAGE_INDEX" \
                -c:a:0 "$OUTPUT_FORMAT" \
                -ar "$TRANSCODER_AUDIO_RATE" \
                -ab "$OUTPUT_BITRATE" \
                -ac "$NUM_CHANNELS" \
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
