#!/bin/bash

THE_DATE_START=$(date '+%Y-%m-%d %H:%M:%S')

AWS_REGION="eu-west-3"
PREFIX_TAG="backend-alfresco-"
SLEEPTIME=10
COMMAND=$1

# Retrieve EC2 INSTANCE ID
INSTANCE_ID=$(aws ec2 describe-instances --filters ''Name=tag:Deployment,Values=$PREFIX_TAG*'' \
  --output text --query 'Reservations[*].Instances[*].InstanceId' --region $AWS_REGION)


if [ -z "$INSTANCE_ID" ]
then
      echo "No instance id found with prefix $PREFIX_TAG in $AWS_REGION region"
      exit 127
else
      echo "Instance $INSTANCE_ID found"
fi

if [ "$COMMAND" == "STOP" ]
then

#https://eu-west-3.console.aws.amazon.com/systems-manager/automation/execute/AWS-StopEC2Instance?region=eu-west-3#InstanceId=i-0e6e1fcee3521a8e2

    EXECUTION_ID=$(aws ssm start-automation-execution --document-name "AWS-StopEC2Instance" --document-version "\$DEFAULT" \
    --parameters "{\"InstanceId\":[\"$INSTANCE_ID\"]}" --region $AWS_REGION --query 'AutomationExecutionId')

    EXECUTION_ID=$(sed -e 's/^"//' -e 's/"$//' <<<"$EXECUTION_ID")
    echo "EXECUTION_ID="$EXECUTION_ID

    STOPPING_STATUS="InProgress"

    while [ "$STOPPING_STATUS" == "InProgress" ]
    do
        STOPPING_STATUS=$(aws ssm get-automation-execution --automation-execution-id "$EXECUTION_ID" \
        --region $AWS_REGION --query 'AutomationExecution.AutomationExecutionStatus')

        STOPPING_STATUS=$(sed -e 's/^"//' -e 's/"$//' <<<"$STOPPING_STATUS")

        echo "STOPPING_STATUS="$STOPPING_STATUS

        sleep $SLEEPTIME
    done

    echo "ALFRESCO INSTANCE STOPPED"
fi


if [ "$COMMAND" == "START" ]
then

    # Start EC2 instance
#https://eu-west-3.console.aws.amazon.com/systems-manager/automation/execute/AWS-StartEC2Instance?region=eu-west-3#InstanceId=i-0e6e1fcee3521a8e2

    EXECUTION_ID=$(aws ssm start-automation-execution --document-name "AWS-StartEC2Instance" --document-version "\$DEFAULT" \
    --parameters "{\"InstanceId\":[\"$INSTANCE_ID\"]}" --region $AWS_REGION --query 'AutomationExecutionId')

    EXECUTION_ID=$(sed -e 's/^"//' -e 's/"$//' <<<"$EXECUTION_ID")
    echo "EXECUTION_ID="$EXECUTION_ID

    STARTING_STATUS="InProgress"

    while [ "$STARTING_STATUS" == "InProgress" ]
    do
        STARTING_STATUS=$(aws ssm get-automation-execution --automation-execution-id "$EXECUTION_ID" \
        --region $AWS_REGION --query 'AutomationExecution.AutomationExecutionStatus')

        STARTING_STATUS=$(sed -e 's/^"//' -e 's/"$//' <<<"$STARTING_STATUS")

        echo "STARTING_STATUS="$STARTING_STATUS

        sleep $SLEEPTIME
    done

    echo "ALFRESCO INSTANCE STARTED"

    # Start Alfresco
    RUNCOMMAND_ID=$(aws ssm send-command --document-name "Kaiac_Command" --document-version "1" \
    --targets "[{\"Key\":\"InstanceIds\",\"Values\":[\"$INSTANCE_ID\"]}]" --parameters "{\"Command\":[\"restart\"]}" \
    --timeout-seconds 600 --max-concurrency "50" --max-errors "0" --region $AWS_REGION --query 'Command.CommandId')
    
    RUNCOMMAND_ID=$(sed -e 's/^"//' -e 's/"$//' <<<"$RUNCOMMAND_ID")
    echo "RUNCOMMAND_ID="$RUNCOMMAND_ID

    
    ALFRESCO_START_STATUS="InProgress"

    while [ "$ALFRESCO_START_STATUS" == "InProgress" ]
    do
        ALFRESCO_START_STATUS=$(aws ssm get-command-invocation --command-id "$RUNCOMMAND_ID" \
        --instance-id "$INSTANCE_ID" --region $AWS_REGION --query 'Status')

        ALFRESCO_START_STATUS=$(sed -e 's/^"//' -e 's/"$//' <<<"$ALFRESCO_START_STATUS")

        echo "ALFRESCO_START_STATUS="$ALFRESCO_START_STATUS

        sleep $SLEEPTIME
    done

fi

if [ "$COMMAND" == "RESTORE" ]
then

    # Restore Alfresco
    RUNCOMMAND_ID=$(aws ssm send-command --document-name "Kaiac_Command" --document-version "1" \
    --targets "[{\"Key\":\"InstanceIds\",\"Values\":[\"$INSTANCE_ID\"]}]" --parameters "{\"Command\":[\"restore\"]}" \
    --timeout-seconds 600 --max-concurrency "50" --max-errors "0" --region $AWS_REGION --query 'Command.CommandId')
    
    RUNCOMMAND_ID=$(sed -e 's/^"//' -e 's/"$//' <<<"$RUNCOMMAND_ID")
    echo "RUNCOMMAND_ID="$RUNCOMMAND_ID

    ALFRESCO_RESTORE_STATUS="InProgress"

    while [ "$ALFRESCO_RESTORE_STATUS" == "InProgress" ]
    do
        ALFRESCO_RESTORE_STATUS=$(aws ssm get-command-invocation --command-id "$RUNCOMMAND_ID" \
        --instance-id "$INSTANCE_ID" --region $AWS_REGION --query 'Status')

        ALFRESCO_RESTORE_STATUS=$(sed -e 's/^"//' -e 's/"$//' <<<"$ALFRESCO_RESTORE_STATUS")

        echo "ALFRESCO_RESTORE_STATUS="$ALFRESCO_RESTORE_STATUS

        sleep $SLEEPTIME
    done

fi


if [ "$COMMAND" == "BACKUP" ]
then

    # BACKUP Alfresco
    RUNCOMMAND_ID=$(aws ssm send-command --document-name "Kaiac_Command" --document-version "1" \
    --targets "[{\"Key\":\"InstanceIds\",\"Values\":[\"$INSTANCE_ID\"]}]" --parameters "{\"Command\":[\"backup\"]}" \
    --timeout-seconds 600 --max-concurrency "50" --max-errors "0" --region $AWS_REGION --query 'Command.CommandId')
    
    RUNCOMMAND_ID=$(sed -e 's/^"//' -e 's/"$//' <<<"$RUNCOMMAND_ID")
    echo "RUNCOMMAND_ID="$RUNCOMMAND_ID

    ALFRESCO_BACKUP_STATUS="InProgress"

    while [ "$ALFRESCO_BACKUP_STATUS" == "InProgress" ]
    do
        ALFRESCO_BACKUP_STATUS=$(aws ssm get-command-invocation --command-id "$RUNCOMMAND_ID" \
        --instance-id "$INSTANCE_ID" --region $AWS_REGION --query 'Status')

        ALFRESCO_BACKUP_STATUS=$(sed -e 's/^"//' -e 's/"$//' <<<"$ALFRESCO_BACKUP_STATUS")

        echo "ALFRESCO_BACKUP_STATUS="$ALFRESCO_BACKUP_STATUS

        sleep $SLEEPTIME
    done

fi

THE_DATE_END=$(date '+%Y-%m-%d %H:%M:%S')
echo "# Start : $THE_DATE_START"
echo "# End : $THE_DATE_END"