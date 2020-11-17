#!/bin/sh

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

### COMPLY SERVER WORK
# Install Replicated/Comply on Comply Node
echo "About to install Replicated and Comply Application Stack."
echo "Please be sure to capture the Kotsadm URL (which should be the IP address"
echo "of ${PROJECT}comply0.classroom.puppet.com) and the randomly generated"
echo "password.  You will need the password to log into kotsadm for the next"
echo "step."
ssh -i ~/.ssh/training.pem -oStrictHostKeyChecking=no centos@${PROJECT}comply0.classroom.puppet.com "sudo setenforce 0; curl -sSL https://k8s.kurl.sh/comply-unstable | sudo bash"
read -rsp $"After copying the URL and password, press any key to continue..." -n1 key

### PUPPET ENTERPRISE WORK
# Setup code in control-repo
## Configure GIT and clone control-repo
mkdir ~/${PROJECT}
cd ~/${PROJECT}
echo "https://root:PuppetClassroomGitlabForYou@${PROJECT}-gitlab.classroom.puppet.com" >> ~/.git-credentials
git config --global user.email ${GIT_USER}
git config --global user.name "${GIT_NAME}"
git config --global credential.helper store
git clone https://${PROJECT}-gitlab.classroom.puppet.com/puppet/control-repo.git

## Add comply module to site-modules in control-repo
cd ${CR_WORK}
git checkout -b ${GIT_BRANCH}
cd ${CR_WORK}/site-modules
tar xf ${CR_BASE}/puppetlabs-comply-${VERSION}.tar
mv puppetlabs-comply-${VERSION} comply

## Push control-repo to project gitlab server
cd ${CR_WORK}
git add .
git commit -m "Added comply package"
git push origin ${GIT_BRANCH}

# Run code manager to get the comply package in place on the PE server
ssh -i ~/.ssh/training.pem -oStrictHostKeyChecking=no centos@${PROJECT}master0.classroom.puppet.com " echo 'puppetlabs' | /usr/local/bin/puppet access login --username admin; /usr/local/bin/puppet code deploy ${GIT_BRANCH} --wait"

# Need to create Puppet Comply classification and add comply node
TOKEN=`curl -s -S -k -X POST -H 'Content-Type: application/json' -d '{"login": "admin", "password": "puppetlabs"}' https://${PROJECT}-master.classroom.puppet.com:4433/rbac-api/v1/auth/token |jq -r '.token'`
curl -s -S -k -X POST -H 'Content-Type: application/json' -H "X-Authentication: $TOKEN" https://${PROJECT}-master.classroom.puppet.com:4433/classifier-api/v1/update-classes?environment=${GIT_BRANCH}

WINNODES=`curl -G -H 'Content-Type: application/json' -H "X-Authentication: $TOKEN" --data-urlencode 'query=["~","certname","win"]' https://${PROJECT}-master.classroom.puppet.com:8081/pdb/query/v4/nodes |jq .[].certname |tr -d \"`

LINNODES=`curl -G -H 'Content-Type: application/json' -H "X-Authentication: $TOKEN" --data-urlencode 'query=["~","certname","nix"]' https://${PROJECT}-master.classroom.puppet.com:8081/pdb/query/v4/nodes |jq .[].certname |tr -d \"`

# Windows in Hydra is currently broken and needs to have the FQDN fixed
for HOST in $WINNODES
do
	echo "Fixing FQDN on $HOST"
	bolt command run "\$agent_ip = (Get-NetIPAddress -AddressFamily IPv4 -SuffixOrigin DHCP).IpAddress; \$agent_name = (Get-WmiObject win32_computersystem).DNSHostName; \$agent_host_entry = \"\${agent_ip} ${HOST} \${agent_name}\"; \$agent_host_entry | Out-File -FilePath C:\\Windows\\System32\\Drivers\\etc\\hosts -Append -Encoding ascii" -t winrm://${HOST} --user administrator --password 'Puppetlabs!' --no-ssl
done

# Add comply to classification of any nodes you want to be scanable
curl -s -S -k -X PUT -H 'Content-Type: application/json' -H "X-Authentication: $TOKEN" -d "{ \"name\": \"Puppet Comply Agents\", \"parent\": \"00000000-0000-4000-8000-000000000000\", \"environment\": \"${GIT_BRANCH}\", \"rule\": [\"~\", [\"fact\",\"clientcert\"], \"[win|nix]\"], \"classes\": {\"comply\": {\"linux_manage_unzip\": true} } }" https://${PROJECT}-master.classroom.puppet.com:4433/classifier-api/v1/groups/00000000-2112-4000-8000-000000000012
