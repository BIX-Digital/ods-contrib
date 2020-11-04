#!/bin/bash

##################################################
## This script can be used to test the
## changes in any quickstarter component
## without the need of provisioning a new app
##
## The prerequisite to run this is to have a running OC
## project along with a project space in Bitbucket
##
## It's inspired by:
## https://github.com/opendevstack/ods-quickstarters/wiki/Run-quickstarter-via-Jenkins
###################################################

echo_done(){
  echo -e "\n\033[92mDONE\033[39m"
}

echo_error(){
  message="$1"
  echo -e "\033[31mERROR\033[39m: $message"
}

echo_info(){
  message="$1"
  echo -e "\033[94mINFO\033[39m: $message"
}

set -eu

USERNAME=
COMPONENT_ID=
PROJECT_ID=
PROXY_URL=
QUICKSTARTER=
AGENT_IMAGE_TAG=
QUICKSTARTER_REF=
SHARED_LIBRARY_REF=
JENKINS_URL=
QUICKSTARTER_REPO=
ODS_NAMESPACE=
ODS_BB_PROJECT=
GROUP_ID=
PACKAGE_NAME=

function usage {
    printf "Usage:\n"
    printf "\t--help|-h\t\t\tPrints the usage\n"
    printf "\t--project-id\t\t\tProject ID of the Bitbucket Project\n"
    printf "\t--component-id\t\t\tComponent ID of the project, usually is equivalent to bitbucket repo name\n"
    printf "\t--username\t\t\tUsername of your Bitbucket account\n"
    printf "\t--quickstarter\t\t\tQuickstarter of interest\n"
    printf "\t--agent-image-tag\t\t[optional, default: latest] Jenkins agent image tag\n"
    printf "\t--quickstarter-git-ref\t\t[optional, default: master] Git ref of quickstarter repository to use\n"
    printf "\t--shared-library-git-ref\t[optional, default: master] Git ref of shared library repository to use\n"
    printf "\t--quickstarter-repo\t\t[optional, default: ods-quickstarters] Quickstarter repository name you want to run the tests on\n"
    printf "\t--ods-namespace\t\t\t[optional, default: ods] Openshift project where your ODS installation is located\n"
    printf "\t--ods-bitbucket-project\t\t[optional, default: opendevstack] Location of your OpenDevStack project fork in your Bitbucket server\n"
    printf "\t--group-id\t\t\t[optional, default: org.opendevstack.<project-id>] Group for e.g. Java based projects\n"
    printf "\t--package-name\t\t\t[optional, default: org.opendevstack.<project-id>.<component-id>] Package name for e.g. Java based projects\n\n"
    printf "\nExample:\n\n"
    printf "\t%s \ \
      \n\t\t--username john_doe@bar.com \ \
      \n\t\t--project-id foo \ \
      \n\t\t--component-id bar \ \
      \n\t\t--quickstarter be-java-springboot \ \
      \n\t\t--agent-image-tag latest \ \
      \n\t\t--quickstarter-git-ref master \ \
      \n\t\t--shared-library-git-ref master \n\n" "$0"
    printf "To learn more you can visit: https://www.opendevstack.org/ods-documentation/\n"
}

while [[ "$#" -gt 0 ]]; do
  case $1 in

   -h|--help) shift
              usage
              exit 0
              ;;

   --project-id) PROJECT_ID="$2"; shift;;
   --project-id=*) PROJECT_ID="${1#*=}";;

   --component-id) COMPONENT_ID="$2"; shift;;
   --component-id=*) COMPONENT_ID="${1#*=}";;

   --username) USERNAME="$2"; shift;;
   --username=*) USERNAME="${1#*=}";;

   --quickstarter) QUICKSTARTER="$2"; shift;;
   --quickstarter=*) QUICKSTARTER="${1#*=}";;

   --agent-image-tag) AGENT_IMAGE_TAG="$2"; shift;;
   --agent-image-tag=*) AGENT_IMAGE_TAG="${1#*=}";;

   --quickstarter-git-ref) QUICKSTARTER_REF="$2"; shift;;
   --quickstarter-git-ref=*) QUICKSTARTER_REF="${1#*=}";;

   --shared-library-git-ref) SHARED_LIBRARY_REF="$2"; shift;;
   --shared-library-git-ref=*) SHARED_LIBRARY_REF="${1#*=}";;

   --quickstarter-repo) QUICKSTARTER_REPO="$2"; shift;;
   --quickstarter-repo=*) QUICKSTARTER_REPO="${1#*=}";;

   --ods-namespace) ODS_NAMESPACE="$2"; shift;;
   --ods-namespace=*) ODS_NAMESPACE="${1#*=}";;

   --ods-bitbucket-project) ODS_BB_PROJECT="$2"; shift;;
   --ods-bitbucket-project=*) ODS_BB_PROJECT="${1#*=}";;

   --group-id) GROUP_ID="$2"; shift;;
   --group-id=*) GROUP_ID="${1#*=}";;

   --package-name) PACKAGE_NAME="$2"; shift;;
   --package-name=*) PACKAGE_NAME="${1#*=}";;

   *) echo_error "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

#############
##### Check required parameters
#############
if [ -z ${PROJECT_ID} ]; then
  echo_error "Param --project-id is missing."; usage; exit 1;
elif [ -z ${COMPONENT_ID} ]; then
  echo_error "Param --component-id is missing."; usage; exit 1;
elif [ -z ${USERNAME} ]; then
  echo_error "Param -u|--username is missing."; usage; exit 1;
elif [ -z ${QUICKSTARTER} ]; then
  echo_error "Param --quickstarter is missing."; usage; exit 1;
fi

#############
##### Set optional parameters
#############
if [ -z ${QUICKSTARTER_REPO} ]; then
  echo_info "Param --quickstarter-repo not defined, setting it to 'ods-quickstarters'"; QUICKSTARTER_REPO="ods-quickstarters";
fi
if [ -z ${ODS_NAMESPACE} ]; then
  echo_info "Param --ods-namespace not defined, setting it to 'ods'"; ODS_NAMESPACE="ods";
fi
if [ -z ${ODS_BB_PROJECT} ]; then
  echo_info "Param --ods-bitbucket-project not defined, setting it to 'opendevstack'"; ODS_BB_PROJECT="opendevstack";
fi
if [ -z ${AGENT_IMAGE_TAG} ]; then
  echo_info "Param --agent-image-tag not defined, setting it to 'latest'"; AGENT_IMAGE_TAG="latest";
fi
if [ -z ${QUICKSTARTER_REF} ]; then
  echo_info "Param --quickstarter-git-ref not defined, setting it to 'master'"; QUICKSTARTER_REF="master";
fi
if [ -z ${SHARED_LIBRARY_REF} ]; then
  echo_info "Param --shared-library-git-ref not defined, setting it to 'master'"; SHARED_LIBRARY_REF="master";
fi
if [ -z ${GROUP_ID} ]; then
  echo_info "Param --group-id not defined, setting it to 'org.opendevstack.${PROJECT_ID}'"; GROUP_ID="org.opendevstack.${PROJECT_ID}";
fi
if [ -z ${PACKAGE_NAME} ]; then
  echo_info "Param --package-name not defined, setting it to 'org.opendevstack.${PROJECT_ID}.${COMPONENT_ID}'"; PACKAGE_NAME="org.opendevstack.${PROJECT_ID}.${COMPONENT_ID}";
fi

#############
##### Check OC login
#############
oc whoami > /dev/null || (echo_error "Please log into openshift using oc login." && exit 1)

#############
##### Select Project
#############
echo "\n"
echo_info "Selecting project to create the pipeline for..."
OPENSHIFT_CD_PROJECT="$PROJECT_ID-cd"
oc project $OPENSHIFT_CD_PROJECT

#############
##### Pull routes
#############
echo_info "Pulling routes of Jenkins and webhook proxy"
JENKINS_URL=$(oc get routes/jenkins --template 'http{{if .spec.tls}}s{{end}}://{{.spec.host}}')
PROXY_URL=$(oc get routes/webhook-proxy --template 'http{{if .spec.tls}}s{{end}}://{{.spec.host}}')
echo_info "Jenkins URL: ${JENKINS_URL}"
echo_info "Webhook Proxy URL: ${PROXY_URL}"

#############
##### Pull the secret from secrets yaml, grep the output of the last word, decode it
#############
echo_info "Pulling webhook trigger secret..."
secret=$(oc get secrets -o=jsonpath='{.items[*].data.trigger-secret}' | base64 --decode)

echo_info "Generating Bitbucket token..."
echo "Please enter your Bitbucket password:"
read -s PASSWORD
if [ "$OSTYPE" == "linux-gnu" ]; then
  token=$(echo "$USERNAME:$PASSWORD" | base64 -w0)
else
  token=$(echo "$USERNAME:$PASSWORD" | base64)
fi

#############
##### Getting Bitbucket Host
#############
echo_info "Pulling your bitbucket host information"
BITBUCKET_URL=$(oc get dc -o=jsonpath='{.items[?(@.metadata.name=="jenkins")].spec.template.spec.containers[*].env[?(@.name=="BITBUCKET_URL")].value}')
echo_info "Bitbucket URL: ${BITBUCKET_URL}"

#############
##### Create Repo
#############
echo_info "Creating repo $COMPONENT_ID in $PROJECT_ID..."
curl --fail --location --request POST "$BITBUCKET_URL/rest/api/1.0/projects/$PROJECT_ID/repos" \
--header "Authorization: Basic $token" \
--header "Content-Type: application/json" \
--data-raw '{
    "name": "'"$PROJECT_ID-$COMPONENT_ID"'"
}
'

#############
##### Create Webhook
#############
echo "\n"
echo_info "Generating webhook for the repo $COMPONENT_ID in $PROJECT_ID..."
PROXY_URL_WITH_SECRET="$PROXY_URL?trigger_secret=$secret"
curl --fail --location --request POST "$BITBUCKET_URL/rest/api/1.0/projects/$PROJECT_ID/repos/$PROJECT_ID-$COMPONENT_ID/webhooks" \
--header "Authorization: Basic $token" \
--header "Content-Type: application/json" \
--data-raw '{
    "name": "Jenkins",
    "events": [
        "repo:refs_changed",
        "pr:merged",
        "pr:declined"
    ],
    "url": "'"$PROXY_URL_WITH_SECRET"'",
    "active": true
}
'

#############
##### Generate Jenkins pipeline postfix
#############
echo "\n"
echo_info "Generating pipeline postfix."
pipelinePostfix=$(openssl rand -base64 15 | tr -dc a-z0-9 | head -c 8)
echo_info "Creating the Jenkins pipeline..."

#############
##### Create pipeline build config
#############
oc process -f ./qs-pipeline.yml \
  -p PROJECT_ID=$PROJECT_ID \
  -p COMPONENT_ID=$COMPONENT_ID \
  -p BITBUCKET_URL=$BITBUCKET_URL \
  -p PIPELINE_POSTFIX=$pipelinePostfix \
  -p QUICKSTARTER=$QUICKSTARTER \
  -p AGENT_IMAGE_TAG=$AGENT_IMAGE_TAG \
  -p QUICKSTARTER_REF=$QUICKSTARTER_REF \
  -p SHARED_LIBRARY_REF=$SHARED_LIBRARY_REF \
  -p QUICKSTARTER_REPO=$QUICKSTARTER_REPO \
  -p ODS_NAMESPACE=$ODS_NAMESPACE \
  -p ODS_BB_PROJECT=$ODS_BB_PROJECT \
  -p GROUP_ID=$GROUP_ID \
  -p PACKAGE_NAME=$PACKAGE_NAME \
  | oc create -n $OPENSHIFT_CD_PROJECT -f -

#############
##### Trigger pipeline build and print the link to logs
#############
PIPELINE_NAME="$OPENSHIFT_CD_PROJECT-ods-quickstarters-$QUICKSTARTER-$pipelinePostfix"
oc start-build "ods-quickstarters-$QUICKSTARTER-$pipelinePostfix"
echo_info "Running the build now. Please check the address below: \n$JENKINS_URL/job/$OPENSHIFT_CD_PROJECT/job/$PIPELINE_NAME/1/console"
echo_done
