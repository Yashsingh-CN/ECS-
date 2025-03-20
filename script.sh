#!/bin/bash
#Constants

REGION=us-west-2
REPOSITORY_NAME=ksi-yash-prod-yash-repo
CLUSTER=ksi-yash-prod-cluster
#FAMILY=`sed -n 's/.*"family": "\(.*\)",/\1/p' taskdef.json`
FAMILY=ksi-yash-prod-yash-ms-task
#NAME=`sed -n 's/.*"name": "\(.*\)",/\1/p' taskdef.json`
NAME=ksi-yash-prod-yash-ms-task
#SERVICE_NAME=${NAME}-service
SERVICE_NAME=ksi-yash-prod-yash-ms-src

echo ${TASK_DEFINITION} > taskdef.json

#Store the repositoryUri as a variable
# --profile ${PROFILE_NAME}
REPOSITORY_URI=`aws ecr describe-repositories --repository-names ${REPOSITORY_NAME} --region ${REGION} | jq .repositories[].repositoryUri | tr -d '"'`

#Replace the build number and respository URI placeholders with the constants above
sed -e "s;%GIT_COMMIT%;${GIT_COMMIT};g" -e "s;%REPOSITORY_URI%;${REPOSITORY_URI};g" taskdef.json > ${NAME}-v_${GIT_COMMIT}.json
#Register the task definition in the repository
aws ecs register-task-definition --family ${FAMILY} --cli-input-json file://${WORKSPACE}/${NAME}-v_${GIT_COMMIT}.json --region ${REGION}
SERVICES=`aws ecs describe-services --services ${SERVICE_NAME} --cluster ${CLUSTER} --region ${REGION} | jq .failures[]`
#Get latest revision
REVISION=`aws ecs describe-task-definition --task-definition ${NAME} --region ${REGION} | jq .taskDefinition.revision`

#Create or update service
if [ "$SERVICES" == "" ]; then
  echo "entered existing service"
  DESIRED_COUNT=`aws ecs describe-services --services ${SERVICE_NAME} --cluster ${CLUSTER} --region ${REGION} | jq .services[].desiredCount`
  if [ ${DESIRED_COUNT} = "0" ]; then
    DESIRED_COUNT="1"
  fi
  aws ecs update-service --cluster ${CLUSTER} --region ${REGION} --service ${SERVICE_NAME} --task-definition ${FAMILY}:${REVISION} --desired-count ${DESIRED_COUNT}
else
  echo "Service Not found, Create service first"
  #aws  --profile ${PROFILE_NAME} ecs create-service --service-name ${SERVICE_NAME} --desired-count 1 --task-definition ${FAMILY} --cluster ${CLUSTER} --region ${REGION}
fi
