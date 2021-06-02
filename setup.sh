#!/bin/sh

PROJECT=$1
ENVIR=$2

if [ "x${PROJECT}" == "x" ];
then
        echo "usage: $0 [project] <env>"
        exit 1
fi
if [ "x${ENVIR}" == "x" ];
then
        ENVIR=production
fi


TRAINING_PEM_FILE="$HOME/.ssh/training.pem"
if [ ! -f $TRAINING_PEM_FILE ];
then
        echo "Error: $TRAINING_PEM_FILE not found."
        exit 1
fi 

# find the assessor file name installed on the primary server
ASSESSOR_CLI_FILE_PATH=$(ssh -i $TRAINING_PEM_FILE centos@${PROJECT}master0.classroom.puppet.com 'ls /opt/puppetlabs/server/data/packages/public/Assessor-CLI*' 2>&1)
ASSESSOR_CLI_FILE=$(basename $ASSESSOR_CLI_FILE_PATH)
if [ -z $ASSESSOR_CLI_FILE ];
then
        echo "Error: Unable to find the Assessor CLI file on the Primary server. Check your PE installation and Assessor installation path."
        exit 1
fi

### PUPPET ENTERPRISE WORK

# Need to create Puppet Comply classification and add comply node
TOKEN=`curl -s -S -k -X POST -H 'Content-Type: application/json' -d '{"login": "admin", "password": "puppetlabs"}' https://${PROJECT}-master.classroom.puppet.com:4433/rbac-api/v1/auth/token |jq -r '.token'`
curl -s -S -k -X POST -H 'Content-Type: application/json' -H "X-Authentication: $TOKEN" https://${PROJECT}-master.classroom.puppet.com:4433/classifier-api/v1/update-classes?environment=${ENVIR}

# Add comply to classification of any nodes you want to be scanable
curl -s -S -k -X PUT -H 'Content-Type: application/json' -H "X-Authentication: $TOKEN" -d "{ \"name\": \"Puppet Comply Agents\", \"parent\": \"00000000-0000-4000-8000-000000000000\", \"environment\": \"${ENVIR}\", \"rule\": [\"~\", [\"fact\",\"clientcert\"], \"[win|nix]\"], \"classes\": {\"comply\": {\"linux_manage_unzip\": true, \"scanner_source\": \"https://puppet.classroom.puppet.com:8140/packages/$ASSESSOR_CLI_FILE\"} }, \"config_data\": {\"archive\": {\"seven_zip_provider\": \"\" } } }" https://${PROJECT}-master.classroom.puppet.com:4433/classifier-api/v1/groups/00000000-2112-4000-8000-000000000012
