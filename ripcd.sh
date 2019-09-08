#!/bin/bash

# Set configuration path
CONFIG_PATH=/etc/autorip.conf

# Get configuration
get_config_var() {
    echo "$(awk -F '=' "/^$1/{print \$2}" $CONFIG_PATH)"
}
OUTPUT_PATH=$(get_config_var OUTPUT_PATH)
OUTPUT_PATH=${OUTPUT_PATH%/}
MUSIC_PATH="$OUTPUT_PATH"/"$(get_config_var MUSIC_DIR)"
MUSIC_CONFIG_PATH=$(get_config_var MUSIC_CONFIG_PATH)
MUSIC_FORMAT=$(get_config_var MUSIC_FORMAT)
MUSIC_RIPPER_BIN=$(get_config_var MUSIC_RIPPER_BIN)

# Ensure ABCDE config reflects autorip config
sed -i "/OUTPUTDIR/c\\OUTPUTDIR=$MUSIC_PATH" "$MUSIC_CONFIG_PATH"

# Execute rip
"$MUSIC_BIN" -d "$DEVNAME" -o "$MUSIC_FORMAT" -N -c "$MUSIC_CONFIG_PATH"

# Eject disc on completion
eject "$DEVNAME"
