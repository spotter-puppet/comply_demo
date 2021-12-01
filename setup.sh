#!/bin/sh

PROJECT=$1
BACKEND=$2
ENVIR=$3

if [ "x${PROJECT}" == "x" ];
then
        echo "usage: $0 [project] <backend> <env>"
        exit 1
fi
if [ "x$BACKEND" == "xdeimos" ];
then
                DOMAIN="se.automationdemos.com"
                SERVER="puppet"
else
                DOMAIN="classroom.puppet.com"
                SERVER="master"
fi
if [ "x${ENVIR}" == "x" ];
then
        ENVIR=production
fi

### PUPPET ENTERPRISE WORK

# Need to create Puppet Comply classification and add comply node
TOKEN=`curl -s -S -k -X POST -H 'Content-Type: application/json' \
        -d '{"login": "admin", "password": "puppetlabs"}' \
        https://${PROJECT}-${SERVER}.${DOMAIN}:4433/rbac-api/v1/auth/token \
        | jq -r '.token'`
curl -s -S -k -X POST -H 'Content-Type: application/json' -H "X-Authentication: $TOKEN" \
    https://${PROJECT}-${SERVER}.${DOMAIN}:4433/classifier-api/v1/update-classes?environment=${ENVIR}

# Add comply to classification of any nodes you want to be scanable
curl -s -S -k -X PUT -H 'Content-Type: application/json' -H "X-Authentication: $TOKEN" \
    -d "{ \"name\": \"Puppet Comply Agents\", \
    \"parent\": \"00000000-0000-4000-8000-000000000000\", \"environment\": \"${ENVIR}\", \
    \"rule\": [\"~\", [\"fact\",\"clientcert\"], \"[win|nix]\"], \"classes\": \
    {\"comply\": {\"linux_manage_unzip\": true, \"scanner_source\": \
        \"https://${PROJECT}comply0.${DOMAIN}:30303/assessor\" } }, \
        \"config_data\": {\"archive\": {\"seven_zip_provider\": \"\" } \
        } }" \
    https://${PROJECT}-${SERVER}.${DOMAIN}:4433/classifier-api/v1/groups/00000000-2112-4000-8000-000000000012

curl -s -S -k -X POST -H 'Content-Type: application/json' -H "X-Authentication: $TOKEN" \
        -d "{ \"environment\": \"\", \"enforce_environment\": false, \"scope\": { \"node_group\": \"00000000-2112-4000-8000-000000000012\" } }" \
        https://${PROJECT}-${SERVER}.${DOMAIN}:8143/orchestrator/v1/command/deploy
