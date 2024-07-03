#!/bin/bash
#description : This script will help to install k8s cluster (master / worker) and gpu operator
#author	     : Moran Guy
#date        : 19/10/2022
#version     : 1.0
#usage       : Please make sure to run this script as ROOT or with ROOT permissions
#notes       : supports ubuntu OS 18.04/20.04/22.04
#==============================================================================
NC='\033[0m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
endpoint=""
k8s_version=""

# ***Disable Swap
function disable-swap {
    swapoff -a
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
}

# ***load kernel modules for support containerd 
function load-kernel-modules {
    tee /etc/modules-load.d/containerd.conf <<EOF
    overlay
    br_netfilter
EOF
    modprobe overlay
    modprobe br_netfilter
}

# ***Setup K8s Networking
function network {
    tee /etc/sysctl.d/kubernetes.conf <<EOF
    net.bridge.bridge-nf-call-ip6tables = 1
    net.bridge.bridge-nf-call-iptables = 1
    net.ipv4.ip_forward = 1
EOF
echo 1 > /proc/sys/net/ipv4/ip_forward
sudo sysctl --system
}

function install-containerd {
        if [ -x "$(command -v containerd)" ]
        then
                echo -e "${GREEN}containerd already installed${NC}"
        else
                echo  -e "${GREEN} installing containerd...${NC}"
                apt install -y curl gpgv gpgsm gnupg-l10n gnupg dirmngr software-properties-common apt-transport-https ca-certificates
                # apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
                rm /etc/apt/trusted.gpg.d/docker.gpg
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg
                add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" -y
                sudo apt update
                sudo apt install -y containerd.io
                containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
                systemctl restart containerd
                systemctl enable containerd
        fi
}

function config-containerd {
    rm /etc/containerd/config.toml
    containerd config default | tee /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml  
    sysctl --system
    service containerd restart
    service kubelet restart  
}

# ***Install K8s
function k8s-install {
	    sudo apt-get update
        sudo apt-get install -y apt-transport-https ca-certificates curl
        rm /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${package_version}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
        echo "package version set to ${package_version}"
        sudo  DEBIAN_FRONTEND=noninteractive apt-get update
	    echo -e "${GREEN} installing kubectl kubeadm kubelet...${NC}"
        sudo  DEBIAN_FRONTEND=noninteractive apt-get install -y kubelet="${k8s_version}-1.1" kubeadm="${k8s_version}-1.1" kubectl="${k8s_version}-1.1"
}

# *** init K8s
function k8s-init {
	echo -e "${GREEN} init k8s...${NC}"
    kubeadm init --pod-network-cidr=10.244.0.0/16 --kubernetes-version=v${k8s_version} --token-ttl 186h --control-plane-endpoint=${endpoint}
    export KUBECONFIG=/etc/kubernetes/admin.conf
    export KUBECONFIG=~/.kube/config
    mkdir -p ${HOME}/.kube
    sudo cp -i /etc/kubernetes/admin.conf ${HOME}/.kube/config
    sudo chown $(id -u):$(id -g) .kube/config
}

# *** Install Helm
function install-helm {
	if [ -x "$(command -v helm)" ]
    then
        echo -e "${GREEN} Helm already installed ${NC}"
    else
		echo -e "${GREEN} Installing Helm ${NC}"
        wget https://get.helm.sh/helm-v3.9.3-linux-amd64.tar.gz
        tar -zxvf helm-v3.9.3-linux-amd64.tar.gz
        sudo mv linux-amd64/helm /usr/local/bin/helm
	fi
		
}
###START HERE###
# *** Accept command line parameter
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        --command)
        command="$2"
        shift
        shift
        ;;
        --k8s-version)
        k8s_version="$2"
        shift
        shift
        ;;
        --endpoint)
        endpoint="$2"
        shift
        shift
        ;;
        *)
        # unknown option
        shift
        ;;
    esac
done

# Print all parameters as confirmation
echo "Command: $command"
echo "Kubernetes Version: $k8s_version"
echo "Endpoint: $endpoint"

# *** Check command parameter and execute corresponding task
if [ "$command" == "1" ]
then
    package_version=${k8s_version%.*}
    disable-swap
    load-kernel-modules
    network
    install-containerd
    config-containerd
    k8s-install
    k8s-init
    install-helm
    echo -e "${GREEN}Now you can join the other nodes to the cluster with the join command below:${NC}"
    kubeadm token create --print-join-command
elif [ "$command" == "2" ]
then
    package_version=${k8s_version%.*}
    disable-swap
    load-kernel-modules
    network
    install-containerd
    config-containerd
    k8s-install
    echo -e "${GREEN}Now node is ready to join the cluster. copy the join command from the master and run here.${NC}"
elif [ "$command" == "3" ]
then
    echo -e "${YELLOW}Reset kubernetes cluster...${NC}"
    kubeadm reset -f
    rm -rf /etc/cni /etc/kubernetes /var/lib/dockershim /var/lib/etcd /var/lib/kubelet /var/run/kubernetes ~/.kube/*
    iptables -F && iptables -X
    iptables -t nat -F && iptables -t nat -X
    iptables -t raw -F && iptables -t raw -X
    iptables -t mangle -F && iptables -t mangle -X
    systemctl restart containerd
    if [ $? == 0 ]
    then 
        echo -e "${GREEN} OK! ${NC}"
    else
        echo -e "${RED}Something went wrong!${NC}"
    fi
    echo -e "${YELLOW}Removing kubeadm kubectl kubelet kubernetes-cni...${NC}"
    sudo apt-get purge -y kubeadm kubectl kubelet kubernetes-cni
    if [ $? == 0 ]
    then 
        echo -e "${GREEN} OK! ${NC}"
    else
        echo -e "${RED}Something went wrong!${NC}"
    fi
    echo -e "${YELLOW}Removing containerd docker...${NC}"
    sudo apt-get purge -y docker* containerd*
    if [ $? == 0 ]
    then
        echo -e "${GREEN} OK! ${NC}"
    else
        echo -e "${RED}Something went wrong!${NC}"
    fi
fi