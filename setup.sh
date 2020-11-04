#!/bin/sh -x

# This script will help setup alpha Comply based on the documentation and artifacts found at
# https://drive.google.com/drive/u/0/folders/0AOywIQsKa0wIUk9PVA
# In particular, you will need to download comply-stack.tar, image_helper.sh, and the puppetlabs-comply module
# Place them in a directory and modify the "CR_BASE" variable below to point to that directory

PROJECT=$1
VERSION=$2
GIT_BRANCH=$3
GIT_USER=spp@unixsa.net
GIT_NAME='Stephen P. Potter'

if [ "x${PROJECT}" == "x" ];
then
        echo "usage: $0 [project] <env>"
        exit 1
fi
if [ "x${GIT_BRANCH}" == "x" ];
then
        GIT_BRANCH=production
fi

CR_BASE="${HOME}/comply_demo/files"
CR_WORK="${HOME}/${PROJECT}/control-repo"

# Setup code in control-repo
#Clone git instance
mkdir ~/${PROJECT}
cd ~/${PROJECT}
echo "https://root:PuppetClassroomGitlabForYou@${PROJECT}-gitlab.classroom.puppet.com" >> ~/.git-credentials
git config --global user.email ${GIT_USER}
git config --global user.name "${GIT_NAME}"
git config --global credential.helper store
git clone https://${PROJECT}-gitlab.classroom.puppet.com/puppet/control-repo.git

cd ${CR_WORK}

git checkout -b ${GIT_BRANCH}

cd ${CR_WORK}/site-modules
tar xf ${CR_BASE}/puppetlabs-comply-${VERSION}.tar
mv puppetlabs-comply-${VERSION} comply

cd ${CR_WORK}
cp ${CR_BASE}/Puppetfile .

git add .
git diff
git commit -m "Added comply package"
git status
sleep 30
git push origin ${GIT_BRANCH}

# Need to add PE IP address on comply node and COMPLY IP address on server node
PE_ADDR=`ssh -i ~/.ssh/training.pem -oStrictHostKeyChecking=no centos@${PROJECT}master0.classroom.puppet.com facter ipaddress`
ssh -i ~/.ssh/training.pem -oStrictHostKeyChecking=no centos@${PROJECT}comply0.classroom.puppet.com "sudo sh -c \"echo $PE_ADDR    puppet.classroom.puppet.com >> /etc/hosts\""
CP_ADDR=`ssh -i ~/.ssh/training.pem -oStrictHostKeyChecking=no centos@${PROJECT}comply0.classroom.puppet.com /usr/sbin/ifconfig -a | awk '/inet 10/ {print $2}'`
ssh -i ~/.ssh/training.pem -oStrictHostKeyChecking=no centos@${PROJECT}master0.classroom.puppet.com "sudo sh -c \"echo $CP_ADDR    comply.classroom.puppet.com >> /etc/hosts\""

# Copy needed files to comply server and run the installer; run the puppet agent installer as well
scp -i ~/.ssh/training.pem ${CR_BASE}/comply-stack-${VERSION}.tar ${CR_BASE}/image_helper.sh ${CR_BASE}/install_comply.sh centos@${PROJECT}comply0.classroom.puppet.com:
ssh -i ~/.ssh/training.pem -oStrictHostKeyChecking=no centos@${PROJECT}comply0.classroom.puppet.com /home/centos/install_comply.sh ${PROJECT}

# Run code manager to get the comply package in place on the PE server
ssh -i ~/.ssh/training.pem -oStrictHostKeyChecking=no centos@${PROJECT}master0.classroom.puppet.com " echo 'puppetlabs' | /usr/local/bin/puppet access login --username admin; /usr/local/bin/puppet code deploy ${GIT_BRANCH} --wait"

# Need to create Puppet Comply classification and add comply node
# Due to setup of hydra, need to set scarp_address to external DNS address of the comply server instead of the default FQDN
TOKEN=`curl -s -S -k -X POST -H 'Content-Type: application/json' -d '{"login": "admin", "password": "puppetlabs"}' https://${PROJECT}-master.classroom.puppet.com:4433/rbac-api/v1/auth/token |jq -r '.token'`

curl -s -S -k -X POST -H 'Content-Type: application/json' -H "X-Authentication: $TOKEN" https://${PROJECT}-master.classroom.puppet.com:4433/classifier-api/v1/update-classes?environment=${GIT_BRANCH}

curl -s -S -k -X PUT -H 'Content-Type: application/json' -H "X-Authentication: $TOKEN" -d "{ \"name\": \"Puppet Comply Server\", \"parent\": \"00000000-0000-4000-8000-000000000000\", \"environment\": \"${GIT_BRANCH}\", \"classes\": {\"comply::app_stack\": {\"scarp_address\": \"${PROJECT}-comply.classroom.puppet.com\"}} }" https://${PROJECT}-master.classroom.puppet.com:4433/classifier-api/v1/groups/00000000-2112-4000-8000-000000000011

curl -s -S -k -X POST -H 'Content-Type: application/json' -H "X-Authentication: $TOKEN" -d "{ \"nodes\": [ \"${PROJECT}comply.classroom.puppet.com\" ] } " https://${PROJECT}-master.classroom.puppet.com:4433/classifier-api/v1/groups/00000000-2112-4000-8000-000000000011/pin

# Add comply to classification of any nodes you want to be scanable
curl -s -S -k -X PUT -H 'Content-Type: application/json' -H "X-Authentication: $TOKEN" -d "{ \"name\": \"Puppet Comply Agents\", \"parent\": \"00000000-0000-4000-8000-000000000000\", \"environment\": \"${GIT_BRANCH}\", \"classes\": {\"comply\": {\"linux_manage_unzip\": \"false\"} } }" https://${PROJECT}-master.classroom.puppet.com:4433/classifier-api/v1/groups/00000000-2112-4000-8000-000000000012

# Since Comply 0.8.0, scans are supposed to be run from the Comply UI only, not from the PE server.  As of 0.8.0, the following still work, but are not the officially
# supported way to perform scans:
# Run comply::ciscat_scan task on nodes, set comply_server to ${PROJECT}-comply.classroom.puppet.com (external address) and
# set benchmark to "CIS_CentOS_Linux_7_Benchmark_v2.2.0-xccdf.xml" for Hydra Linux instances
