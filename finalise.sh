#!/bin/bash

# Finalise the video rip

# Set configuration path
CONFIG_PATH=/etc/autorip.conf

# Get configuration
get_config_var() {
    echo "$(awk -F '=' "/^$1/{print \$2}" $CONFIG_PATH)"
}
OUTPUT_PATH=$(get_config_var OUTPUT_PATH)
OUTPUT_PATH=${OUTPUT_PATH%/}
STAGING_FOLDER=$(get_config_var STAGING_FOLDER)
VIDEO_WORKING_PATH=$(get_config_var VIDEO_WORKING_PATH)
# Protection to make sure the working path is NOT root directory
if [ "$VIDEO_WORKING_PATH" == "/" ] ; then
    exit 1
fi
VIDEO_WORKING_PATH=${VIDEO_WORKING_PATH%/}
ACTIVE_FILE="active"
VIDEO_TITLER_BIN=$(get_config_var VIDEO_TITLER_BIN)
VIDEO_MOVIES_DIR=$(get_config_var VIDEO_MOVIES_DIR)
VIDEO_MOVIES_DB=$(get_config_var VIDEO_MOVIES_DB)
VIDEO_MOVIES_FORMAT=$(get_config_var VIDEO_MOVIES_FORMAT)
VIDEO_TELEVISION_DIR=$(get_config_var VIDEO_TELEVISION_DIR)
VIDEO_TELEVISION_DB=$(get_config_var VIDEO_TELEVISION_DB)
VIDEO_TELEVISION_FORMAT=$(get_config_var VIDEO_TELEVISION_FORMAT)

# Configure formats
MOVIES_FORMAT=${VIDEO_MOVIES_FORMAT%\"}
MOVIES_FORMAT=${MOVIES_FORMAT#\"}
TELEVISION_FORMAT=${VIDEO_TELEVISION_FORMAT%\"}
TELEVISION_FORMAT=${TELEVISION_FORMAT#\"}
MOVIES_FORMAT=\""$OUTPUT_PATH"/"$VIDEO_MOVIES_DIR"/"$MOVIES_FORMAT"\"
TELEVISION_FORMAT=\""$OUTPUT_PATH"/"$VIDEO_TELEVISION_DIR"/"$TELEVISION_FORMAT"\"

# Get the last disc working path
ACTIVE_FILE_PATH="$VIDEO_WORKING_PATH"/"$ACTIVE_FILE"
if [ -f "$ACTIVE_FILE_PATH" ] ; then
    ACTIVE_LABEL=$(sed '1q;d' "$ACTIVE_FILE_PATH")
    ACTIVE_PATH=$(sed '2q;d' "$ACTIVE_FILE_PATH")
    if [ -d "$ACTIVE_PATH" ] ; then
        # Finalise
        NUM_VIDEO_FILES=$(ls "$ACTIVE_PATH" | wc -l)
        if [ $NUM_VIDEO_FILES -gt 1 ] ; then
            # Television
            QUERY_DB="$VIDEO_TELEVISION_DB"
            RENAME_FORMAT="$TELEVISION_FORMAT"
            # Pull down the series episode list and apply a quick absolute
            # file rename before the proper rename
            ABSOLUTE_EPISODE_LIST=$("$VIDEO_TITLER_BIN" -list --db "$QUERY_DB" --q "$ACTIVE_LABEL")
            NUM_EPISODES=$(wc -l <<< $ABSOLUTE_EPISODE_LIST)
            for EPISODE_PATH in "$ACTIVE_PATH"/* ; do
                ABSOLUTE_EPISODE_NUM=$(grep -Eo '[0-9]+$' <<< ${EPISODE_PATH:0:-4})
                EPISODE_NAME=$(sed "$ABSOLUTE_EPISODE_NUM q;d" <<< $ABSOLUTE_EPISODE_LIST)
                mv "$EPISODE_PATH" "$ACTIVE_PATH$EPISODE_NAME${EPISODE_PATH: -4}"
            done
        else
            # Movie
            QUERY_DB="$VIDEO_MOVIES_DB"
            RENAME_FORMAT="$MOVIES_FORMAT"
        fi
        $VIDEO_TITLER_BIN -rename "$ACTIVE_PATH" --db "$QUERY_DB" --q "$ACTIVE_LABEL" --format "$RENAME_FORMAT" -non-strict
    fi
    # Delete the active file
    rm "$ACTIVE_FILE_PATH"
fi

# If everything has been done correctly, we should be able to remove the
# working directory...
rmdir "$VIDEO_WORKING_PATH"
