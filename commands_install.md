# Install Ansible
```
sudo apt update && \
sudo apt install software-properties-common --yes && \
sudo apt-add-repository --update ppa:ansible/ansible --yes && \
sudo apt install ansible --yes
```

# Install Packer
```
sudo apt-get install unzip --yes && \
wget https://releases.hashicorp.com/packer/1.5.1/packer_1.5.1_linux_amd64.zip && \
unzip packer_1.5.1_linux_amd64.zip && \
sudo mv packer /usr/local/bin && \
rm packer_1.5.1_linux_amd64.zip
```

# Install Terraform
```
sudo apt-get install wget unzip –yes
wget https://releases.hashicorp.com/terraform/1.1.8/terraform_1.1.8_linux_amd64.zip && \
unzip terraform_1.1.8_linux_amd64.zip && \
sudo mv terraform /usr/local/bin/ && \
rm terraform_1.1.8_linux_amd64.zip && \
terraform -v
```

# Create Directory
```
mkdir TP_CICD && cd TP_CICD 
mkdir Deploy_WebSite Build_WebAMI Deploy_Infra && cd Deploy_WebSite && touch main.tf
```