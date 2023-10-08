#!/bin/bash

AWS_REGION="eu-west-3"
TAG_NAME="Deployment"
TAG_VALUE_PREFIX="backend-alfresco-*"
ALFRESCO_URL="https://backend-alfresco-staging.skyscaledev.com/alfresco/"
API_SEND_COMMAND_URL="https://lambda.skyscaledev.com/send_command"
WAIT_INTERVAL=5
P_COMMAND=$1
CLI_MODE="API"
APP_LOCAL_FOLDER="/vagrant/demo-kaiac-alfresco"

# Définition des codes de couleur ANSI
ORANGE='\033[38;5;208m'
GREEN_BG='\033[42m'
WHITE='\033[97m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
YELLOW_BG='\033[0;103m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color


function echo_step(){
    label=$1
    echo -e "${GREEN_BG}$label${NC}"
}

function echo_result(){
    label=$1
    echo -e "${GREEN}$label${NC}"
}

function echo_status(){
    label=$1
    status=$2
    if [ "$status" == "Success" ] 
    then
        echo -e "$label=${ORANGE}$status${NC}"
    else
        echo -e "$label=${WHITE}$status${NC}"
    fi
}

function retrieve_instance_id_api(){
    aws_region=$1
    tag_name=$2
    tag_value_prefix=$3

    instance_id=$(curl -s --location ''$API_SEND_COMMAND_URL'' \
        --header 'Content-Type: application/json' \
        --data "{\"command\": \"GET_INSTANCE_ID\",
                    \"awsRegion\": \"$aws_region\",
                    \"tagName\": \"$tag_name\",
                    \"tagPrefixValue\": \"$tag_value_prefix\"}" | jq -r '.instanceId')
    echo $instance_id
}

function retrieve_instance_id_aws(){
    aws_region=$1
    tag_name=$2
    tag_value_prefix=$3

    instance_id=$(aws ec2 describe-instances --filters ''Name=tag:$tag_name,Values=$tag_value_prefix Name=instance-state-name,Values=running,pending,stopped'' \
        --output text --query 'Reservations[*].Instances[*].InstanceId' --region $aws_region)
    echo $instance_id
}

function retrieve_instance_id(){
    aws_region=$1
    tag_name=$2
    tag_value_prefix=$3

    if [ "$CLI_MODE" == "API" ]
    then
        retrieve_instance_id_api $aws_region $tag_name $tag_value_prefix
    else
        retrieve_instance_id_aws $aws_region $tag_name $tag_value_prefix
    fi
}

function show_final_result(){
    result_to_show=$1
    echo -e ${GREEN_BG}
    echo "$result_to_show"
    echo -e ${NC}
}

check_instance_status(){
    instance_status=$1
    if [ -z "$instance_status" ]
    then
        echo -e "${RED}No instance id found with prefix $TAG_VALUE_PREFIX in $AWS_REGION region${NC}"
    else
        echo -e "${GREEN_BG}Statut de l'instance : ${instance_status}${NC}"      
    fi
}

function retrieve_instance_status_api(){
    aws_region=$1
    tag_name=$2
    tag_value_prefix=$3

    instance_status=$(curl -s --location ''$API_SEND_COMMAND_URL'' \
        --header 'Content-Type: application/json' \
        --data "{\"command\": \"GET_INSTANCE_STATUS\",
                    \"awsRegion\": \"$aws_region\",
                    \"tagName\": \"$tag_name\",
                    \"tagPrefixValue\": \"$tag_value_prefix\"}" | jq -r '.instanceStatus')
    

    check_instance_status $instance_status
}

function retrieve_instance_status_aws(){
    aws_region=$1
    tag_name=$2
    tag_value_prefix=$3

    instance_status=$(aws ec2 describe-instances --filters ''Name=tag:$tag_name,Values=$tag_value_prefix* Name=instance-state-name,Values=running,pending,stopped'' \
        --output text --query 'Reservations[*].Instances[*].State.Name' --region $aws_region)

    check_instance_status $instance_status
}

function retrieve_instance_status(){
    aws_region=$1
    tag_name=$2
    tag_value_prefix=$3

    if [ "$CLI_MODE" == "API" ]
    then
        retrieve_instance_status_api $aws_region $tag_name $tag_value_prefix
    else
        retrieve_instance_status_aws $aws_region $tag_name $tag_value_prefix
    fi
}

function remove_quotes(){
    str=$1
    str_no_quotes=$(sed -e 's/^"//' -e 's/"$//' <<<"$str")
    echo $str_no_quotes
}

function start_automation_execution_api(){
    aws_region=$1
    ssm_document=$2
    instance_id=$3

    execution_id=$(curl -s --location ''$API_SEND_COMMAND_URL'' \
    --header 'Content-Type: application/json' \
    --data "{\"command\": \"START_SSM_AUTOMATION\",
                \"awsRegion\": \"$aws_region\",
                \"instanceId\": \"$instance_id\",
                \"ssmDocument\": \"$ssm_document\"}" | jq -r '.executionId')

    echo $execution_id
}

function start_automation_execution_aws(){
    aws_region=$1
    ssm_document=$2
    instance_id=$3

    execution_id=$(aws ssm start-automation-execution --document-name "$ssm_document" --document-version "\$DEFAULT" \
    --parameters "{\"InstanceId\":[\"$instance_id\"]}" --region $aws_region --query 'AutomationExecutionId')

    execution_id=$(remove_quotes $execution_id)
    echo $execution_id
}

function start_automation_execution(){
    aws_region=$1
    ssm_document=$2
    instance_id=$3

    if [ "$CLI_MODE" == "API" ]
    then
        start_automation_execution_api $aws_region $ssm_document $instance_id
    else
        start_automation_execution_aws $aws_region $ssm_document $instance_id
    fi
}

function get_automation_execution_api(){
    aws_region=$1
    execution_id=$2
    label=$3
    interval=$4

    STATUS="InProgress"

    while [ "$STATUS" == "InProgress" ]
    do

        STATUS=$(curl -s --location ''$API_SEND_COMMAND_URL'' \
            --header 'Content-Type: application/json' \
            --data "{\"command\": \"STATUS_SSM_AUTOMATION\",
                        \"awsRegion\": \"$aws_region\",
                        \"executionId\": \"$execution_id\"}" | jq -r '.executionStatus')
        
        echo_status $label $STATUS

        sleep $interval
    done

}

function get_automation_execution_aws(){
    aws_region=$1
    execution_id=$2
    label=$3
    interval=$4

    STATUS="InProgress"

    while [ "$STATUS" == "InProgress" ]
    do
        STATUS=$(aws ssm get-automation-execution --automation-execution-id "$execution_id" \
        --region $aws_region --query 'AutomationExecution.AutomationExecutionStatus')

        STATUS=$(remove_quotes $STATUS)
        
        echo_status $label $STATUS

        sleep $interval
    done

}

function get_automation_execution(){
    aws_region=$1
    execution_id=$2
    label=$3
    interval=$4

    if [ "$CLI_MODE" == "API" ]
    then
        get_automation_execution_api $aws_region $execution_id $label $interval
    else
        get_automation_execution_aws $aws_region $execution_id $label $interval
    fi

}

function send_kaiac_command_api(){
    aws_region=$1
    instance_id=$2
    commands=$3
    document_name=$4

    command_id=$(curl -s --location ''$API_SEND_COMMAND_URL'' \
        --header 'Content-Type: application/json' \
        --data "{\"command\": \"SEND_KAIAC_COMMAND\",
                    \"awsRegion\": \"$aws_region\",
                    \"instanceId\": \"$instance_id\",
                    \"commands\": \"$commands\",
                    \"documentName\": \"$document_name\"}" | jq -r '.commandId')

    echo $command_id
}

function send_kaiac_command_aws(){
    aws_region=$1
    instance_id=$2
    commands=$3
    document_name=$4

    command_id=$(aws ssm send-command --document-name "$document_name" --document-version "1" \
    --targets "[{\"Key\":\"InstanceIds\",\"Values\":[\"$instance_id\"]}]" --parameters "{\"commands\":[\"$commands\"]}" \
    --timeout-seconds 600 --max-concurrency "50" --max-errors "0" --region $aws_region --query 'Command.CommandId')

    command_id=$(remove_quotes $command_id)
    echo $command_id
}

function send_kaiac_command(){
    aws_region=$1
    instance_id=$2
    command_name=$3
    document_name=$4

    if [ "$CLI_MODE" == "API" ]
    then
        send_kaiac_command_api $aws_region $instance_id $command_name $document_name
    else
        send_kaiac_command_aws $aws_region $instance_id $command_name $document_name
    fi
}



function get_command_invocation_api(){
    aws_region=$1
    command_id=$2
    instance_id=$3
    label=$4
    interval=$5

    STATUS="InProgress"

    while [ "$STATUS" == "InProgress" ]
    do

        STATUS=$(curl -s --location ''$API_SEND_COMMAND_URL'' \
        --header 'Content-Type: application/json' \
        --data "{
            \"command\": \"STATUS_KAIAC_COMMAND\",
            \"awsRegion\": \"$aws_region\",
            \"instanceId\":\"$instance_id\",
            \"commandId\": \"$command_id\"
            }"  | jq -r '.commandStatus')

        echo_status $label $STATUS

        sleep $interval
    done

}

function get_command_invocation_aws(){
    aws_region=$1
    command_id=$2
    instance_id=$3
    label=$4
    interval=$5

    STATUS="InProgress"

    while [ "$STATUS" == "InProgress" ]
    do
        STATUS=$(aws ssm get-command-invocation --command-id "$command_id" \
        --instance-id "$instance_id" --region $aws_region --query 'Status')

        STATUS=$(remove_quotes $STATUS)

        echo_status $label $STATUS

        sleep $interval
    done

}

function get_command_invocation(){
    aws_region=$1
    command_id=$2
    instance_id=$3
    label=$4
    interval=$5

    if [ "$CLI_MODE" == "API" ]
    then
        get_command_invocation_api $aws_region $command_id $instance_id $label $interval
    else
        get_command_invocation_aws $aws_region $command_id $instance_id $label $interval
    fi

}


# Fonction pour afficher un message d'attente
function afficher_attente() {
    interval=$1 # Intervalle en secondes entre les messages
    while true; do
        echo_status "ALFRESCO_WEBSITE_STATUS" "InProgress"
        sleep $interval
    done
}

function wait_alfresco_to_be_ready(){
    alfresco_url=$1 # URL que vous souhaitez appeler
    interval=$2 # Intervalle en secondes entre les messages

    # Exécution de la fonction d'attente en arrière-plan
    afficher_attente $interval &

    # Stocker le PID du processus d'attente
    pid_attente=$!

    # Appel à l'URL
    curl -s -o /dev/null $alfresco_url

    # Tuer le processus d'attente
    kill $pid_attente

    # Vérification du code de retour de curl
    if [ $? -eq 0 ]; then
        echo_status "ALFRESCO_WEBSITE_STATUS" "Success"
        echo_result "L'appel à l'URL $alfresco_url a réussi."
    else
        echo_status "ALFRESCO_WEBSITE_STATUS" "Failed"
        echo_result "L'appel à l'URL $alfresco_url a échoué."
    fi
}


# Fonction pour choisir le mode API ou le mode AWS CLI
choisir_mode() {
    echo -e -n "Communiquer via API (${BLUE}Y${NC}/N)? : "
    read -r choix
    #echo -e "Enter kaiac root folder [${BLUE}/root${NC}]: " 
    if [ "$choix" == "N" ] 
    then
        CLI_MODE="AWSCLI"
    else
        CLI_MODE="API"
    fi
}

# Fonction pour afficher le menu d'options
afficher_menu() {
    echo -e "MODE:${RED}$CLI_MODE${NC}"
    echo -e "${BLUE}OPTIONS :${NC}"
    echo -e "${BLUE}1${NC}. STOP"
    echo -e "${BLUE}2${NC}. START"
    echo -e "${BLUE}3${NC}. RESTORE"
    echo -e "${BLUE}4${NC}. BACKUP"
    echo -e "${BLUE}5${NC}. START & RESTORE"
    echo -e "${BLUE}6${NC}. STATUS"
    echo -e "${BLUE}7${NC}. MONITOR ALFRESCO"
    echo -e "${BLUE}8${NC}. Quitter"
}

show_title() {
    title=$1
    echo -e "${GREEN}$title${NC}"
}

get_date_seconds(){
    SECS=$(date '+%s')
    echo $SECS
}

show_duration(){
    p_start=$1
    THE_DATE_END=$(get_date_seconds)
    duree=$((THE_DATE_END - p_start))
    printf "Le traitement a pris "
    printf ${RED}
    printf '%dh:%dm:%ds\n' $((duree/3600)) $((duree%3600/60)) $((duree%60))
    printf ${NC}
}




check_instance_id(){
    instance_id=$1
    if [ -z "$instance_id" ]
    then
        echo "No instance id found with prefix $TAG_VALUE_PREFIX in $AWS_REGION region"
        exit 127      
    fi
}

# Fonction pour exécuter l'option 1
executer_STOP() {
    THE_DATE_START=$(get_date_seconds)

    instance_id=$1

    check_instance_id $instance_id

    show_title "Vous avez choisi de stopper votre instance ALFRESCO."
    # Stop EC2 instance
    echo_step "Etape 1/1 : Arrêt de l'instance EC2 en cours"
    EXECUTION_ID=$(start_automation_execution $AWS_REGION "AWS-StopEC2Instance" $instance_id)
    get_automation_execution $AWS_REGION $EXECUTION_ID "STOPPING_STATUS" $WAIT_INTERVAL
    echo_step "Etape 1/1 : Arrêt de l'instance EC2 terminé"

    show_duration $THE_DATE_START
}

# Fonction pour exécuter l'option 2
executer_START() {
    THE_DATE_START=$(get_date_seconds)

    instance_id=$1

    check_instance_id $instance_id

    show_title "Vous avez choisi de démarrer votre instance ALFRESCO."
    # Start EC2 instance
    echo_step "Etape 1/3 : Démarrage de l'instance EC2 en cours"
    EXECUTION_ID=$(start_automation_execution $AWS_REGION "AWS-StartEC2Instance" $instance_id)
    get_automation_execution $AWS_REGION $EXECUTION_ID "STARTING_STATUS" $WAIT_INTERVAL
    echo_step "Etape 1/3 : Démarrage de l'instance EC2 terminé"
    echo ""

    # Start Docker containers
    echo_step "Etape 2/3 : Démarrage des containers Docker en cours"
    RUNCOMMAND_ID=$(send_kaiac_command $AWS_REGION $instance_id "$APP_LOCAL_FOLDER/restart.sh" "AWS-RunShellScript")
    get_command_invocation $AWS_REGION $RUNCOMMAND_ID $instance_id "DOCKER_START_STATUS" $WAIT_INTERVAL
    echo_step "Etape 2/3 : Démarrage des containers Docker terminé"
    echo ""

    # Start Alfresco
    echo_step "Etape 3/3 : Démarrage d'ALFRESCO en cours"
    wait_alfresco_to_be_ready $ALFRESCO_URL $WAIT_INTERVAL
    echo_step "Etape 3/3 : Démarrage d'ALFRESCO terminé"

    show_duration $THE_DATE_START
}

# Fonction pour exécuter l'option 3
executer_RESTORE() {
    THE_DATE_START=$(get_date_seconds)

    instance_id=$1

    check_instance_id $instance_id

    show_title "Vous avez choisi de restaurer vos données ALFRESCO."
    # Restore Alfresco
    echo_step "Etape 1/2 : Restauration en cours"
    RUNCOMMAND_ID=$(send_kaiac_command $AWS_REGION $instance_id "$APP_LOCAL_FOLDER/restore.sh" "AWS-RunShellScript")
    get_command_invocation $AWS_REGION $RUNCOMMAND_ID $instance_id "ALFRESCO_RESTORE_STATUS" $WAIT_INTERVAL
    echo_step "Etape 1/2 : Restauration terminée"
    echo ""

    # Start Alfresco
    echo_step "Etape 2/2 : Démarrage d'ALFRESCO en cours"
    wait_alfresco_to_be_ready $ALFRESCO_URL $WAIT_INTERVAL
    echo_step "Etape 2/2 : Démarrage d'ALFRESCO terminé"

    show_duration $THE_DATE_START
}

# Fonction pour exécuter l'option 4
executer_BACKUP() {
    THE_DATE_START=$(get_date_seconds)

    instance_id=$1

    check_instance_id $instance_id

    show_title "Vous avez choisi de sauvegarder vos données ALFRESCO."
    # BACKUP Alfresco
    echo_step "Etape 1/1 : Sauvegarde en cours"
    RUNCOMMAND_ID=$(send_kaiac_command $AWS_REGION $instance_id "$APP_LOCAL_FOLDER/backup.sh" "AWS-RunShellScript")
    get_command_invocation $AWS_REGION $RUNCOMMAND_ID $instance_id "ALFRESCO_BACKUP_STATUS" $WAIT_INTERVAL
    echo_step "Etape 1/1 : Sauvegarde terminée"

    show_duration $THE_DATE_START
}


# Fonction pour exécuter l'option 5
executer_START_RESTORE() {
    THE_DATE_START=$(get_date_seconds)

    instance_id=$1

    check_instance_id $instance_id

    show_title "Vous avez choisi de redémarrer l'instance et restaurer vos données ALFRESCO."
    # Start EC2 instance
    echo_step "Etape 1/3 : Démarrage de l'instance EC2 en cours"
    EXECUTION_ID=$(start_automation_execution $AWS_REGION "AWS-StartEC2Instance" $instance_id)
    get_automation_execution $AWS_REGION $EXECUTION_ID "STARTING_STATUS" $WAIT_INTERVAL
    echo_step "Etape 1/3 : Démarrage de l'instance EC2 terminé"
    echo ""

    # Restore Alfresco
    echo_step "Etape 2/3 : Restauration en cours"
    RUNCOMMAND_ID=$(send_kaiac_command $AWS_REGION $instance_id "$APP_LOCAL_FOLDER/restore.sh" "AWS-RunShellScript")
    get_command_invocation $AWS_REGION $RUNCOMMAND_ID $instance_id "ALFRESCO_RESTORE_STATUS" $WAIT_INTERVAL
    echo_step "Etape 2/3 : Restauration terminée"
    echo ""

    # Start Alfresco
    echo_step "Etape 3/3 : Démarrage d'ALFRESCO en cours"
    wait_alfresco_to_be_ready $ALFRESCO_URL $WAIT_INTERVAL
    echo_step "Etape 3/3 : Démarrage d'ALFRESCO terminé"

    show_duration $THE_DATE_START
}

# Fonction pour exécuter l'option 6
executer_STATUS() {
    THE_DATE_START=$(get_date_seconds)

    # Retrieve EC2 INSTANCE STATUS
    retrieve_instance_status $AWS_REGION $TAG_NAME $TAG_VALUE_PREFIX

    show_duration $THE_DATE_START
}

# Fonction pour exécuter l'option 7
executer_MONITOR_ALFRESCO() {
    THE_DATE_START=$(get_date_seconds)

    # Monitor Alfresco
    echo_step "Monitoring d'ALFRESCO en cours"
    wait_alfresco_to_be_ready $ALFRESCO_URL $WAIT_INTERVAL
    echo_step "Monitoring d'ALFRESCO terminé"

    show_duration $THE_DATE_START
}

# choisir le mode
choisir_mode

# Retrieve EC2 INSTANCE ID
INSTANCE_ID=$(retrieve_instance_id $AWS_REGION $TAG_NAME $TAG_VALUE_PREFIX)

if [ "$P_COMMAND" == "STOP" ]
then
    executer_STOP $INSTANCE_ID
    exit
fi

if [ "$P_COMMAND" == "START" ]
then
    executer_START $INSTANCE_ID
    exit
fi

if [ "$P_COMMAND" == "RESTORE" ]
then
    executer_RESTORE $INSTANCE_ID
    exit
fi

if [ "$P_COMMAND" == "BACKUP" ]
then
    executer_BACKUP $INSTANCE_ID
    exit
fi

if [ "$P_COMMAND" == "START_RESTORE" ]
then
    executer_START_RESTORE $INSTANCE_ID
    exit
fi

if [ "$P_COMMAND" == "STATUS" ]
then
    executer_STATUS
    exit
fi


# Afficher le menu initial
afficher_menu

# Demander à l'utilisateur de choisir une option
while true; do
    echo -e -n "Choisissez une option (${BLUE}1-8${NC}) : "
    read -r choix

    case $choix in
        1) executer_STOP $INSTANCE_ID ;;
        2) executer_START $INSTANCE_ID ;;
        3) executer_RESTORE $INSTANCE_ID ;;
        4) executer_BACKUP $INSTANCE_ID ;;
        5) executer_START_RESTORE $INSTANCE_ID ;;
        6) executer_STATUS ;;
        7) executer_MONITOR_ALFRESCO ;;
        8) echo -e "${GREEN}Au revoir !${NC}" ; exit ;;
        *) echo -e "${RED}Option invalide.${NC} Veuillez choisir une option valide (${BLUE}1-8${NC})." ;;
    esac

    # Afficher à nouveau le menu
    afficher_menu
done


