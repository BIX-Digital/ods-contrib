#!/usr/bin/env bash
set -ue
set -o pipefail

##################################################
## This script can be used to create an empty
## repository, setup with webhooks.
###################################################

BITBUCKET_URL=""
COMPONENT_ID=""
PROJECT_ID=""
TEMPLATE_URL=""

function usage {
    printf "Usage:\n"
    printf "\t--help|-h\t\t\tPrints the usage\n"
    printf "\t-v|--verbose\tVerbose output\n"
    printf "\t--bitbucket\tBitbucket URL, e.g. 'https://bitbucket.example.com'\n"
    printf "\t--project\tProject ID of the Bitbucket Project\n"
    printf "\t--component\tComponent ID of the project, usually is equivalent to bitbucket repo name\n"
    printf "\t--template\tTemplate URL to use for new repository (must be a .tgz file like https://github.com/bix-digital/ods-pipeline-examples/tarball/jupyter-lab)\n"
}

while [[ "$#" -gt 0 ]]; do case $1 in
  -v|--verbose) set -x;;

  -h|--help) usage; exit 0;;

  --bitbucket=*) BITBUCKET_URL="${1#*=}";;
  --bitbucket)   BITBUCKET_URL="$2"; shift;;

  --project)   PROJECT_ID="$2"; shift;;
  --project=*) PROJECT_ID="${1#*=}";;

  --component)   COMPONENT_ID="$2"; shift;;
  --component=*) COMPONENT_ID="${1#*=}";;

  --template)   TEMPLATE_URL="$2"; shift;;
  --template=*) TEMPLATE_URL="${1#*=}";;

  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

#############
##### Check required parameters
#############
if [ -z ${PROJECT_ID} ]; then
  echo "Param --project is missing."; usage; exit 1;
elif [ -z ${COMPONENT_ID} ]; then
  echo "Param --component is missing."; usage; exit 1;
fi

#############
##### Set variables
#############
# Project name is all lowercase
PROJECT_ID=$(echo "${PROJECT_ID}" | tr '[:upper:]' '[:lower:]')
# Component name is all lowercase
COMPONENT_ID=$(echo "${COMPONENT_ID}" | tr '[:upper:]' '[:lower:]')
# Bitbucket repository is all lowercase
BITBUCKET_REPO_NAME=$(echo "${PROJECT_ID}-${COMPONENT_ID}" | tr '[:upper:]' '[:lower:]')
# Bitbucket project is all uppercase
BITBUCKET_PROJECT=$(echo "${PROJECT_ID}" | tr '[:lower:]' '[:upper:]')
# OpenShift project is all lowercase
OPENSHIFT_CD_PROJECT=$(echo "$PROJECT_ID-cd" | tr '[:upper:]' '[:lower:]')

#############
##### Checks
#############
echo "Performing checks ..."
command -v git &> /dev/null || (echo "You need to install 'git' to use this script." && exit 1)
if [ -d "${BITBUCKET_REPO_NAME}" ]; then
  echo "Directory ${BITBUCKET_REPO_NAME} already exists in working directory."; exit 1;
fi
command -v oc &> /dev/null || (echo "You need to install 'oc' to use this script." && exit 1)
oc whoami > /dev/null || (echo "Please log into OpenShift using 'oc login'." && exit 1)

#############
##### Execute
#############
echo "Pulling info from OpenShift ..."
webhookURL=$(oc -n "${OPENSHIFT_CD_PROJECT}" get routes/ods-pipeline --template 'http{{if .spec.tls}}s{{end}}://{{.spec.host}}/bitbucket')
webhookSecret=$(oc -n "${OPENSHIFT_CD_PROJECT}" get secret/ods-bitbucket-webhook -o=jsonpath='{.data.secret}' | base64 --decode)

echo "Please enter a Bitbucket access token with admin permissions:"
read -s BITBUCKET_TOKEN
basicAuthHeader="Authorization: Bearer ${BITBUCKET_TOKEN}"

echo "Creating Bitbucket repository ..."
curl -sS -X POST "$BITBUCKET_URL/rest/api/1.0/projects/$BITBUCKET_PROJECT/repos" \
  -H "${basicAuthHeader}" \
  -H "Content-Type: application/json" \
  -d '{"name": "'"$BITBUCKET_REPO_NAME"'"}'

echo ""
echo "Configuring repository webhook ..."
curl -sS -X POST "$BITBUCKET_URL/rest/api/1.0/projects/$BITBUCKET_PROJECT/repos/$BITBUCKET_REPO_NAME/webhooks" \
  -H "${basicAuthHeader}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ODS Pipeline",
    "events": [
        "repo:refs_changed"
    ],
    "configuration": {
        "secret": "'"$webhookSecret"'"
    },
    "url": "'"$webhookURL"'",
    "active": true
}
'

echo ""
echo "Cloning created repository ..."
git clone "${BITBUCKET_URL}/scm/${BITBUCKET_PROJECT}/${BITBUCKET_REPO_NAME}.git"

if [ -n "${TEMPLATE_URL}" ]; then
  command -v tar &> /dev/null || (echo "You need to install 'tar' to populate from template." && exit 1)
  echo "Populating repository with template ..."
  cd "${BITBUCKET_REPO_NAME}"
  curl -L "${TEMPLATE_URL}" | tar -xz
  shopt -s dotglob
  mv */* .

  command -v sed &> /dev/null || (echo "You need to install 'sed' to manipulate the template." && exit 1)
  echo "Replacing @project@ and @component@ in template ..."
  if [ -f ods.yaml ]; then
    sed -i '' "s/@project@/${PROJECT_ID}/" ods.yaml
    sed -i '' "s/@component@/${COMPONENT_ID}/" ods.yaml
  fi
  if [ -f ods.yml ]; then
    sed -i '' "s/@project@/${PROJECT_ID}/" ods.yaml
    sed -i '' "s/@component@/${COMPONENT_ID}/" ods.yaml
  fi
  if [ -f chart/Chart.yaml ]; then
    sed -i '' "s/@project@/${PROJECT_ID}/" chart/Chart.yaml
    sed -i '' "s/@component@/${COMPONENT_ID}/" chart/Chart.yaml
  fi

  echo ""
  echo "Repository has been populated from the template in your working copy."
  echo "Adjust and commit the files as needed."
fi

echo ""
echo "Done"
