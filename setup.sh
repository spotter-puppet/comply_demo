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

### PUPPET ENTERPRISE WORK

# Need to create Puppet Comply classification and add comply node
TOKEN=`curl -s -S -k -X POST -H 'Content-Type: application/json' \
        -d '{"login": "admin", "password": "puppetlabs"}' \
        https://${PROJECT}-master.classroom.puppet.com:4433/rbac-api/v1/auth/token |jq -r '.token'`
curl -s -S -k -X POST -H 'Content-Type: application/json' -H "X-Authentication: $TOKEN" \
    https://${PROJECT}-master.classroom.puppet.com:4433/classifier-api/v1/update-classes?environment=${ENVIR}

# Add comply to classification of any nodes you want to be scanable
curl -s -S -k -X PUT -H 'Content-Type: application/json' -H "X-Authentication: $TOKEN" \
    -d "{ \"name\": \"Puppet Comply Agents\", \
    \"parent\": \"00000000-0000-4000-8000-000000000000\", \"environment\": \"${ENVIR}\", \
    \"rule\": [\"~\", [\"fact\",\"clientcert\"], \"[win|nix]\"], \"classes\": \
    {\"comply\": {\"linux_manage_unzip\": true, \"scanner_source\": \
	\"https://${PROJECT}comply0.classroom.puppet.com:30303/assessor\" } }, \
	\"config_data\": {\"archive\": {\"seven_zip_provider\": \"\" } \
	} }" \
    https://${PROJECT}-master.classroom.puppet.com:4433/classifier-api/v1/groups/00000000-2112-4000-8000-000000000012
    
curl -s -S -k -X POST -H 'Content-Type: application/json' -H "X-Authentication: $TOKEN" \
	-d "{ \"environment\": \"\", \"enforce_environment\": false, \"scope\": { \"node_group\": \"00000000-2112-4000-8000-000000000012\" } }" \
	https://${PROJECT}-master.classroom.puppet.com:8143/orchestrator/v1/command/deploy
    
