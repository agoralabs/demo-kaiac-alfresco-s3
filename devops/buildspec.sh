#!/bin/bash

THE_DATE=$(date '+%Y-%m-%d %H:%M:%S')
echo "Build started on $THE_DATE"

appenvsubstr(){
    p_template=$1
    p_destination=$2
    envsubst '$TF_VAR_ENV_APP_GL_SCRIPT_MODE' < $p_template \
    | envsubst '$TF_VAR_ENV_APP_GL_NAME' \
    | envsubst '$TF_VAR_ENV_APP_GL_STAGE' \
    | envsubst '$TF_VAR_ENV_APP_BE_DOMAIN_NAME' \
    | envsubst '$TF_VAR_ENV_APP_BE_URL' \
    | envsubst '$TF_VAR_ENV_APP_BE_LOCAL_PORT' \
    | envsubst '$TF_VAR_ENV_APP_BE_LOCAL_SOURCE_FOLDER' \
    | envsubst '$TF_VAR_ENV_APP_GL_DEVOPS_BACKUP_FILENAME' \
    | envsubst '$TF_VAR_ENV_APP_GL_DEVOPS_BACKUP_S3_BUCKET' \
    | envsubst '$TF_VAR_ENV_APP_GL_DEVOPS_BACKUP_AUTO' \
    | envsubst '$TF_VAR_ENV_APP_GL_DEVOPS_RESTORE_AUTO' \
    | envsubst '$TF_VAR_ENV_APP_GL_AWS_REGION_ECR' \
    | envsubst '$TF_VAR_ENV_APP_GL_DOCKER_REPOSITORY' \
    | envsubst '$TF_VAR_ENV_APP_GL_REPO_ALFRESCO_CRC_TAG' \
    | envsubst '$TF_VAR_ENV_APP_GL_REPO_ALFRESCO_SEARCH_SVC_TAG' \
    | envsubst '$TF_VAR_ENV_APP_GL_REPO_ALFRESCO_SHARE_TAG' \
    | envsubst '$TF_VAR_ENV_APP_GL_REPO_ALFRESCO_CONTENT_APP_TAG' \
    | envsubst '$TF_VAR_ENV_APP_GL_REPO_ALFRESCO_POSTGRE_TAG' \
    | envsubst '$TF_VAR_ENV_APP_GL_REPO_MARIA_DB_TAG' \
    | envsubst '$TF_VAR_ENV_APP_GL_REPO_ALFRESCO_TFRM_CORE_AIO_TAG' \
    | envsubst '$TF_VAR_ENV_APP_GL_REPO_ALFRESCO_ACTIVEMQ_TAG' > $p_destination
}

appenvsubstr devops/appspec.yml.template appspec.yml
appenvsubstr devops/appspec.sh.template devops/appspec.sh
chmod 777 devops/appspec.sh

appenvsubstr devops/backup.sh.template backup.sh
chmod 777 backup.sh

appenvsubstr devops/restore.sh.template restore.sh
chmod 777 restore.sh

appenvsubstr devops/restart.sh.template restart.sh
chmod 777 restart.sh

appenvsubstr devops/.env.template .env

