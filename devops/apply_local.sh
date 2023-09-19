#!/bin/bash

THE_DATE=$(date '+%Y-%m-%d %H:%M:%S')
echo "Build started on $THE_DATE"

source_folder=$TF_VAR_ENV_APP_BE_LOCAL_SOURCE_FOLDER

# mkdir -p $source_folder/tmp
# chmod 777 $source_folder/tmp

# arraytpl=($(ls -d $source_folder/devops/*.template))

# for template in "${arraytpl[@]}"
# do
#     pattern=${template%.template}
#     generated=${pattern##*/}
#     log_msg "generate $generated file..."
#     pattern=${template%.template}
#     appenvsubstr $template $source_folder/$generated
# done

#creation des volumes et positionnement des permissions
mkdir -p $source_folder/data/alf-repo-data
chown -R 33000 $source_folder/data/alf-repo-data

mkdir -p $source_folder/logs/alfresco
chown -R 33000 $source_folder/logs/alfresco

mkdir -p $source_folder/data/solr-data
chown 33007 $source_folder/data/solr-data

mkdir -p $source_folder/data/postgres-data
chown -R 999 $source_folder/data/postgres-data

mkdir -p $source_folder/logs/postgres
chown -R 999 $source_folder/logs/postgres

mkdir -p $source_folder/data/activemq-data
chown -R 33031 $source_folder/data/activemq-data


appenvsubstr $source_folder/devops/backup.sh.template $source_folder/backup.sh
chmod 777 $source_folder/backup.sh

appenvsubstr $source_folder/devops/restore.sh.template $source_folder/restore.sh
chmod 777 $source_folder/restore.sh

appenvsubstr $source_folder/devops/.env.template $source_folder/.env

log_msg "Login into ecr..."
aws ecr get-login-password --region $TF_VAR_ENV_APP_GL_AWS_REGION_ECR | docker login --username AWS --password-stdin $TF_VAR_ENV_APP_GL_AWS_ACCOUNT_ID.dkr.ecr.$TF_VAR_ENV_APP_GL_AWS_REGION_ECR.amazonaws.com
log_msg "Run docker compose..."
docker compose -f $source_folder/docker-compose.yml up -d --build --force-recreate