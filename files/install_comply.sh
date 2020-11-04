PROJECT=$1
sudo yum install -y yum-untils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io
sudo systemctl start docker
sudo docker run hello-world
sudo docker run -d -p 5000:5000 --restart=always --name registry registry:2
chmod 755 image_helper.sh
sudo ~centos/image_helper.sh ~centos/comply-stack.tar ${PROJECT}comply0.classroom.puppet.com:5000
curl -k https://puppet.classroom.puppet.com:8140/packages/current/install.bash | sudo bash
