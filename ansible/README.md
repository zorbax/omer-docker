# Vagrant sandbox

## Prerequisites

For GNU/Linux and MacOS Intel users:

- Vagrant
- VirtualBox
- Ansible

## Usage

```bash
vagrant up
vagrant ssh ansible-host
ansible omero -i inventory.yaml -m ping -u vagrant
```

