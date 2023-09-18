#!/bin/bash

source_folder="/vagrant/demo-kaiac-alfresco-s3"

if [ $(crontab -l | grep "$source_folder/backup.sh") ] 
then
    echo "already scheduled"
else
    echo "to be scheduled"
    crontab -l > tmpcron
    #echo new cron into cron file
    echo "*/2 * * * * $source_folder/backup.sh" >> tmpcron
    #install new cron file
    #crontab tmpcron
    #rm tmpcron

fi