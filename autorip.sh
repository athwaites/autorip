#!/bin/bash

if [ "$ID_CDROM_MEDIA_CD" = 1 ]
then
    echo "Audio"
elif [ "$ID_CDROM_MEDIA_DVD" = 1 ]
then
    echo "DVD"
elif [ "$ID_CDROM_MEDIA_BD" = 1 ]
then
    echo "Blu-Ray"
fi
