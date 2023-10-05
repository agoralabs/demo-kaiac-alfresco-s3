#!/bin/bash

AWS_REGION="eu-west-3"
TAG_NAME="Deployment"
TAG_VALUE_PREFIX="backend-alfresco-"
ALFRESCO_URL="https://backend-alfresco-staging.skyscaledev.com/alfresco/"
API_SEND_COMMAND_URL="https://lambda.skyscaledev.com/send_command"
WAIT_INTERVAL=5
P_COMMAND=$1
CLI_MODE="API"

BLUE='\033[0;34m'
YELLOW='\033[0;33m'
YELLOW_BG='\033[0;103m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color


function retrieve_instance_id_api(){
    aws_region=$1
    tag_name=$2
    tag_value_prefix=$3

    instance_id=$(curl -s --location ''$API_SEND_COMMAND_URL'' \
        --header 'Content-Type: application/json' \
        --data '{"command": "GET_INSTANCE_ID"}' | jq -r '.instanceId')
    echo $instance_id
}

function retrieve_instance_id_aws(){
    aws_region=$1
    tag_name=$2
    tag_value_prefix=$3

    instance_id=$(aws ec2 describe-instances --filters ''Name=tag:$tag_name,Values=$tag_value_prefix* Name=instance-state-name,Values=running,pending,stopped'' \
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
                \"executionId\": \"$execution_id\"}" | jq -r '.executionStatus')
        
        echo "$label="$STATUS

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
        
        echo "$label="$STATUS

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
    command_name=$3

    command_id=$(curl -s --location ''$API_SEND_COMMAND_URL'' \
        --header 'Content-Type: application/json' \
        --data "{\"command\": \"SEND_KAIAC_COMMAND\",
            \"instanceId\": \"$instance_id\",
            \"kaiacCommand\": \"$command_name\"}" | jq -r '.commandId')

    echo $command_id
}

function send_kaiac_command_aws(){
    aws_region=$1
    instance_id=$2
    command_name=$3

    command_id=$(aws ssm send-command --document-name "Kaiac_Command" --document-version "1" \
    --targets "[{\"Key\":\"InstanceIds\",\"Values\":[\"$instance_id\"]}]" --parameters "{\"Command\":[\"$command_name\"]}" \
    --timeout-seconds 600 --max-concurrency "50" --max-errors "0" --region $aws_region --query 'Command.CommandId')

    command_id=$(remove_quotes $command_id)
    echo $command_id
}

function send_kaiac_command(){
    aws_region=$1
    instance_id=$2
    command_name=$3

    if [ "$CLI_MODE" == "API" ]
    then
        send_kaiac_command_api $aws_region $instance_id $command_name
    else
        send_kaiac_command_aws $aws_region $instance_id $command_name
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
            \"instanceId\":\"$instance_id\",
            \"commandId\": \"$command_id\"
            }"  | jq -r '.commandStatus')

        echo "$label="$STATUS

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

        echo "$label="$STATUS

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

function wait_alfresco_to_be_ready_old(){
    alfresco_url=$1 # URL que vous souhaitez appeler
    interval=$2 # Intervalle en secondes entre les messages

    echo "WAITING ALFRESCO TO BE READY"
    until $(curl --output /dev/null --silent --head --fail $alfresco_url); do
        echo 'ALFRESCO IS READY'
        sleep $interval
    done
}


# Fonction pour afficher un message d'attente
function afficher_attente() {
    interval=$1 # Intervalle en secondes entre les messages
    while true; do
        echo "ALFRESCO_WEBSITE_STATUS=InProgress"
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
        echo "ALFRESCO_WEBSITE_STATUS=Success"
        echo "L'appel à l'URL $alfresco_url a réussi."
    else
        echo "ALFRESCO_WEBSITE_STATUS=Failed"
        echo "L'appel à l'URL $alfresco_url a échoué."
    fi
}

# Fonction pour afficher le menu d'options
afficher_menu() {
    echo -e "${BLUE}OPTIONS :${NC}"
    echo -e "${BLUE}1${NC}. STOP"
    echo -e "${BLUE}2${NC}. START"
    echo -e "${BLUE}3${NC}. RESTORE"
    echo -e "${BLUE}4${NC}. BACKUP"
    echo -e "${BLUE}5${NC}. START & RESTORE"
    echo -e "${BLUE}6${NC}. Quitter"
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

# Fonction pour exécuter l'option 1
executer_STOP() {
    THE_DATE_START=$(get_date_seconds)

    instance_id=$1
    show_title "Vous avez choisi de stopper votre instance ALFRESCO."
    # Stop EC2 instance
    EXECUTION_ID=$(start_automation_execution $AWS_REGION "AWS-StopEC2Instance" $instance_id)
    #echo "EXECUTION_ID="$EXECUTION_ID
    get_automation_execution $AWS_REGION $EXECUTION_ID "STOPPING_STATUS" $WAIT_INTERVAL
    
    show_duration $THE_DATE_START
}

# Fonction pour exécuter l'option 2
executer_START() {
    THE_DATE_START=$(get_date_seconds)

    instance_id=$1
    show_title "Vous avez choisi de démarrer votre instance ALFRESCO."
    # Start EC2 instance
    EXECUTION_ID=$(start_automation_execution $AWS_REGION "AWS-StartEC2Instance" $instance_id)
    #echo "EXECUTION_ID="$EXECUTION_ID
    get_automation_execution $AWS_REGION $EXECUTION_ID "STARTING_STATUS" $WAIT_INTERVAL

    # Start Alfresco
    RUNCOMMAND_ID=$(send_kaiac_command $AWS_REGION $instance_id "restart")
    #echo "RUNCOMMAND_ID="$RUNCOMMAND_ID
    get_command_invocation $AWS_REGION $RUNCOMMAND_ID $instance_id "DOCKER_START_STATUS" $WAIT_INTERVAL

    wait_alfresco_to_be_ready $ALFRESCO_URL $WAIT_INTERVAL
 
    show_duration $THE_DATE_START
}

# Fonction pour exécuter l'option 3
executer_RESTORE() {
    THE_DATE_START=$(get_date_seconds)

    instance_id=$1
    show_title "Vous avez choisi de restaurer vos données ALFRESCO."
    # Restore Alfresco
    RUNCOMMAND_ID=$(send_kaiac_command $AWS_REGION $instance_id "restore")
    #echo "RUNCOMMAND_ID="$RUNCOMMAND_ID
    get_command_invocation $AWS_REGION $RUNCOMMAND_ID $instance_id "ALFRESCO_RESTORE_STATUS" $WAIT_INTERVAL

    wait_alfresco_to_be_ready $ALFRESCO_URL $WAIT_INTERVAL

    show_duration $THE_DATE_START
}

# Fonction pour exécuter l'option 4
executer_BACKUP() {
    THE_DATE_START=$(get_date_seconds)

    instance_id=$1
    show_title "Vous avez choisi de sauvegarder vos données ALFRESCO."
    # BACKUP Alfresco
    RUNCOMMAND_ID=$(send_kaiac_command $AWS_REGION $instance_id "backup")
    #echo "RUNCOMMAND_ID="$RUNCOMMAND_ID

    get_command_invocation $AWS_REGION $RUNCOMMAND_ID $instance_id "ALFRESCO_BACKUP_STATUS" $WAIT_INTERVAL

    show_duration $THE_DATE_START
}


# Fonction pour exécuter l'option 5
executer_START_RESTORE() {
    THE_DATE_START=$(get_date_seconds)

    instance_id=$1
    show_title "Vous avez choisi de redémarrer l'instance et restaurer vos données ALFRESCO."
    # Start EC2 instance
    EXECUTION_ID=$(start_automation_execution $AWS_REGION "AWS-StartEC2Instance" $instance_id)
    #echo "EXECUTION_ID="$EXECUTION_ID
    get_automation_execution $AWS_REGION $EXECUTION_ID "STARTING_STATUS" $WAIT_INTERVAL

    # Restore Alfresco
    RUNCOMMAND_ID=$(send_kaiac_command $AWS_REGION $instance_id "restore")
    #echo "RUNCOMMAND_ID="$RUNCOMMAND_ID
    get_command_invocation $AWS_REGION $RUNCOMMAND_ID $instance_id "ALFRESCO_RESTORE_STATUS" $WAIT_INTERVAL

    wait_alfresco_to_be_ready $ALFRESCO_URL $WAIT_INTERVAL

    show_duration $THE_DATE_START
}

# Retrieve EC2 INSTANCE ID
INSTANCE_ID=$(retrieve_instance_id $AWS_REGION $TAG_NAME $TAG_VALUE_PREFIX)


if [ -z "$INSTANCE_ID" ]
then
      echo "No instance id found with prefix $TAG_VALUE_PREFIX in $AWS_REGION region"
      exit 127      
fi

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

# Afficher le menu initial
afficher_menu

# Demander à l'utilisateur de choisir une option
while true; do
    read -p "Choisissez une option (1-6) : " choix

    case $choix in
        1) executer_STOP $INSTANCE_ID ;;
        2) executer_START $INSTANCE_ID ;;
        3) executer_RESTORE $INSTANCE_ID ;;
        4) executer_BACKUP $INSTANCE_ID ;;
        5) executer_START_RESTORE $INSTANCE_ID ;;
        6) echo "Au revoir !" ; exit ;;
        *) echo "Option invalide. Veuillez choisir une option valide (1-6)." ;;
    esac

    # Afficher à nouveau le menu
    afficher_menu
done


