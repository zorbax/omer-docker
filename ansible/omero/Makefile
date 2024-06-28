.ONESHELL:
SHELL=/bin/bash

export ANSIBLE_CONFIG := ~/.ansible.cfg

default: playbook

roles:
	@ansible-galaxy install -r requirements.yml

playbook: roles
	@ansible-playbook -vv playbook.yml

