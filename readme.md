this ansible script will copy kube-install.sh to all host and execute it to install all kubernetes dependency and containerd configuration.

this script can also setup control plane (kube-install.sh --command 1), but currently it must be run manually and the kubeadm join command must also be copied and run manually. (though it really is possible if want to be automated).

this script only compatible with ubuntu version 21 and up due to different containerd cgroup configuration.