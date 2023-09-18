#!/bin/bash

THE_DATE=$(date '+%Y-%m-%d %H:%M:%S')
echo "Build started on $THE_DATE"

source_folder=$TF_VAR_ENV_APP_BE_LOCAL_SOURCE_FOLDER

rm -rf $source_folder/data

rm -rf $source_folder/logs

docker volume rm $(docker volume ls -q)