#!/bin/bash

if [ "$ID_CDROM_MEDIA_CD" = 1 ]
then
    # Process Audio CD
elif [ "$ID_CDROM_MEDIA_DVD" = 1 ]
then
    # Process DVD
elif [ "$ID_CDROM_MEDIA_BD" = 1 ]
then
    # Process Blu-Ray
fi
