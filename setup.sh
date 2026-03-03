#!/bin/bash
echo "=== INSTALLATION ELASTICSEARCH TP ==="

# Installation Docker
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Démarrer Docker
sudo service docker start
sudo usermod -aG docker $USER

# Lancer Elasticsearch
docker run -d --name elasticsearch -p 9200:9200 -p 9300:9300 -e "discovery.type=single-node" -e "xpack.security.enabled=false" docker.elastic.co/elasticsearch/elasticsearch:8.11.0

# Python
sudo apt install -y python3 python3-pip python3-venv
python3 -m venv ~/elastic-tp/venv
source ~/elastic-tp/venv/bin/activate
pip install elasticsearch sentence-transformers pandas numpy jupyter

echo "Installation terminée!"
echo "Test: curl localhost:9200"
