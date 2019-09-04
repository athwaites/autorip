#!/bin/bash

CONFIG_PATH=/etc/autorip.conf

rip_cd() {

}

rip_dvd() {

}

rip_bd() {

}

if [ "$ID_CDROM_MEDIA_CD" = 1 ]; then
    rip_cd
elif [ "$ID_CDROM_MEDIA_DVD" = 1 ]; then
    rip_dvd
elif [ "$ID_CDROM_MEDIA_BD" = 1 ]; then
    rip_bd
fi
