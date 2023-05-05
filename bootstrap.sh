#-----------------------------------
#
# do not run this script as root
#
#-----------------------------------

#!/bin/bash

IP=
NFS_IP=
NFS_PATH=

# basic setup
sudo sed -i 's/1/0/g' /etc/apt/apt.conf.d/20auto-upgrades

# disable ufw
sudo systemctl stop ufw
sudo systemctl disable ufw

# ssh configuration
ssh-keygen -t rsa
ssh-copy-id -i ~/.ssh/id_rsa ${USER}@${IP}

# install basic packages
sudo apt update
sudo apt install -y python3-pip net-tools nfs-common whois xfsprogs

# download deepops repository
cd ~
git clone https://github.com/NVIDIA/deepops.git -b release-22.04
cd deepops

# enable kubectl & kubeadm auto-completion
echo "source <(kubectl completion bash)" >> ${HOME}/.bashrc
echo "source <(kubeadm completion bash)" >> ${HOME}/.bashrc
echo "source <(kubectl completion bash)" | sudo tee -a /root/.bashrc
echo "source <(kubeadm completion bash)" | sudo tee -a /root/.bashrc

# Install software prerequisites and copy default configuration
# this will create collections and config directory under deepops directory
# kubespray submodules are located under deepops/submodules/kubespray
bash ./scripts/setup.sh

# activate ansible
source ${HOME}/.bashrc

# edit the inventory
sed -i "s/#mgmt01/mgmt01/g" config/inventory
sed -i "s/10.0.0.1/${IP}/g" config/inventory
sed -i'' -r -e "/\[kube-node\]/a\mgmt01" config/inventory

# disable changing hostnames of the hosts following as the inventory
#sed -i "s/deepops_set_hostname: true/deepops_set_hostname: false/g" config/group_vars/all.yml

# activate container level nvidia driver(default) then no reboot will be occurred
# if below command is commented, host level nvidia driver 515.105.01 will be installed and reboot will also occur. Then you must rerun ansible-playbook one more time after reboot
sed -i "s/gpu_operator_preinstalled_nvidia_software: true/gpu_operator_preinstalled_nvidia_software: false/g" config/group_vars/k8s-cluster.yml

# force install NVIDIA driver even if GPU not detected
#sed -i "s/nvidia_driver_force_install: false/nvidia_driver_force_install: true/g" config/group_vars/all.yml

# change cri from containerd to docker
#sed -i "s/container_manager: containerd/container_manager: docker/g" config/group_vars/k8s-cluster.yml
# install docker latest version
#sed -i "s/docker_version: '20.10'/docker_version: 'latest'/g" config/group_vars/all.yml  

# disable nfs provisioner
sed -i "s/k8s_nfs_client_provisioner: true/k8s_nfs_client_provisioner: false/g" config/group_vars/k8s-cluster.yml
# use existing nfs export directory
#sed -i "s/k8s_nfs_mkdir: true/k8s_nfs_mkdir: false/g" config/group_vars/k8s-cluster.yml
# use existing nfs server
#sed -i "s/k8s_deploy_nfs_server: true/k8s_deploy_nfs_server: false/g" config/group_vars/k8s-cluster.yml
#sed -i "s/{{ groups\[\"kube-master\"\]\[0\] }}/${NFS_IP}/g" config/group_vars/k8s-cluster.yml
#sed -i 's:\/export\/deepops_nfs:${NFS_PATH}:g' config/group_vars/k8s-cluster.yml

# install extra software packages
sed -i "s/#software_extra_packages:/software_extra_packages:/g" config/group_vars/all.yml
sed -i "s/#  - curl/  - curl/g" config/group_vars/all.yml
sed -i "s/#  - git/  - git/g" config/group_vars/all.yml
sed -i "s/#  - tmux/  - tmux/g" config/group_vars/all.yml
sed -i "s/#  - vim/  - vim/g" config/group_vars/all.yml
sed -i "s/#  - wget/  - wget/g" config/group_vars/all.yml
sed -i "s/#  - build-essential/  - build-essential/g" config/group_vars/all.yml

# deploy k8s
ansible-playbook -l k8s-cluster playbooks/k8s-cluster.yml -K
# deploy nfs provisioner manually
#ansible-playbook playbooks/k8s-cluster/nfs-client-provisioner.yml
# create administrative user and access token for dashboard
./scripts/k8s/deploy_dashboard_user.sh
# deploy monitoring(prometheus and grafana)
./scripts/k8s/deploy_monitoring.sh

# enable to access ngc
#kubectl create secret docker-registry nvcr.dgxkey --docker-server=nvcr.io --docker-username=\$oauthtoken --docker-email=<email> --docker-password=<NGC API Key>