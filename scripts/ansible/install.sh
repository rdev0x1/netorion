#!/bin/bash

set -e

ANSIBLE_ROLES_PATH="./roles"

echo "Installing production environment..."
ANSIBLE_ROLES_PATH=$ANSIBLE_ROLES_PATH ansible-playbook -i inventory/hosts.ini playbooks/netorion.yml
