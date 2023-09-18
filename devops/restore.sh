#!/bin/sh

current_folder=$PWD
# get the files from S3
aws s3api head-object --bucket kaiac.agoralabs.org --key alf_data.zip || NOT_EXIST=true
if [ $NOT_EXIST ]; then
  echo "File does not exist."
else
    aws s3 cp s3://kaiac.agoralabs.org/alf_data.zip .

    cd /vagrant/demo-kaiac-alfresco/data/alf-repo-data

    unzip -qq $current_folder/alf_data.zip

fi

