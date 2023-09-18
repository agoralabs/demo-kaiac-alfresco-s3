#!/bin/sh

source_folder=/vagrant/demo-kaiac-alfresco
data_file="alfresco_backup.zip"
TF_VAR_ENV_APP_GL_DEVOPS_BACKUP_S3_BUCKET="kaiac.agoralabs.org"
# get the files from S3
aws s3api head-object --bucket $TF_VAR_ENV_APP_GL_DEVOPS_BACKUP_S3_BUCKET --key $data_file || NOT_EXIST=true
if [ $NOT_EXIST ]; then
  echo "File does not exist."
else

  mkdir $source_folder/restore
  #récupération du backup
  aws s3 cp s3://$TF_VAR_ENV_APP_GL_DEVOPS_BACKUP_S3_BUCKET/$data_file .
  cd $source_folder/restore
  unzip -qq $source_folder/$data_file
  
  #arrêt des containers et suppression des volumes
  docker compose -f $source_folder/docker-compose.yml down
  docker volume rm $(docker volume ls -q | grep alfresco_postgres)

  #deploiement de postgre
  docker compose -f $source_folder/docker-compose.yml up postgres

  #chargement du dump
  cat $source_folder/restore/pg-dump.sql | docker-compose exec -T postgres psql --username alfresco --password alfresco

  #Arrêt de postgre
  docker compose -f $source_folder/docker-compose.yml stop postgres

  #restauration des données
  cp -r $source_folder/restore/alf-repo-data $source_folder/data

  #lancement des containers
  docker compose -f $source_folder/docker-compose.yml up -d --build --force-recreate

fi

