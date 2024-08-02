.ONESHELL:
SHELL=/bin/bash

export ANSIBLE_CONFIG := ./config/ansible.cfg

default: up

sshkey:
ifeq ($(wildcard ~/.ssh/vagrant),)
	@ssh-keygen -t rsa -b 2048 -f ~/.ssh/vagrant -N ""
endif

up: sshkey destroy
	@echo "==> UP <=="
	@vagrant up

destroy:
	@echo "==> DESTROY <=="
	@vagrant destroy -f

