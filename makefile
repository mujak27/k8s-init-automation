.PHONY: ansible

ansible:
	ansible-playbook ansible/tasks.yaml -i ansible/inventory.yaml

disable-swap:
	ansible-playbook ansible/disable-swap.yaml -i ansible/inventory.yaml

poweroff:
	ansible-playbook ansible/poweroff.yaml -i ansible/inventory.yaml

reboot:
	ansible-playbook ansible/reboot.yaml -i ansible/inventory.yaml

containerd-cgroup:
	ansible-playbook ansible/containerd-cgroup.yaml -i ansible/inventory.yaml