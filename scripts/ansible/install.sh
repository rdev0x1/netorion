#!/bin/bash

set -e

ANSIBLE_ROLES_PATH="./roles"

# Check if the first argument is "dev"
if [[ $1 == "dev" ]]; then
    echo "Installing development environment..."
    ANSIBLE_ROLES_PATH=$ANSIBLE_ROLES_PATH ansible-playbook -i inventory/hosts.ini playbooks/dev.yml
else
    echo "Installing production environment..."
    ANSIBLE_ROLES_PATH=$ANSIBLE_ROLES_PATH ansible-playbook -i inventory/hosts.ini playbooks/netorion.yml
fi
