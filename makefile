.PHONY: ansible

ansible:
	ansible-playbook ansible/copy.yaml -i ansible/inventory.yaml
