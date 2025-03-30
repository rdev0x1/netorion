#!/bin/bash

set -e

# Variables
VM_NAME="netorion-vm"
# We cannot genericcloud image because cloudinit does not work.
IMAGE_NAME="debian-12-generic-amd64.qcow2"
BASE_IMAGE_PATH="./output/${IMAGE_NAME}"
DEBIAN_URL="https://cdimage.debian.org/images/cloud/bookworm/latest/${IMAGE_NAME}"
IMAGE_SHA512="75db35c328863c6c84cb48c1fe1d7975407af637b272cfb8c87ac0cc0e7e89c8a1cc840c2d6d82794b53051a1131d233091c4f4d5790557a8540f0dc9fc4f631"
IMAGE_STORAGE_PATH="/data/virt/disk/${VM_NAME}.qcow2"

RAM_MB=4096
VCPUS=4
VM_CLOUD_INIT_TEMPLATE="./cloud-init-template.yaml"
VM_CLOUD_INIT="./output/cloud-init.yaml"

NETWORK="default"
BRIDGE_NAME="orionbr0"

# Function to detect the Linux distribution and set package manager
detect_distro() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
  else
    echo "Cannot detect the Linux distribution. /etc/os-release not found."
    exit 1
  fi

  case "$DISTRO" in
  ubuntu | debian)
    PKG_MANAGER="apt"
    INSTALL_CMD="sudo apt install -y"
    sudo apt update
    ;;
  void)
    PKG_MANAGER="xbps"
    INSTALL_CMD="sudo xbps-install -Sy"
    sudo xbps-install -Syu
    ;;
  *)
    echo "Unsupported Linux distribution: $DISTRO"
    echo "Please install the required dependencies manually."
    exit 1
    ;;
  esac
}

# Function to check if a command exists
command_exists() {
  command -v "$1" &>/dev/null
}

# Function to install dependencies
install_dependencies() {
  echo "Installing dependencies using $PKG_MANAGER..."

  # Define the list of dependencies with alternative package names separated by '|'
  # Format: "primary_pkg|alternative_pkg1|alternative_pkg2"
  DEPENDENCIES=(
    "qemu|qemu-system-x86"
    "libvirt|libvirt-clients-qemu"
    "virt-install|virtinst"
    "virsh"
    "ansible"
    "git"
    "wget"
    "virtiofsd"
    "gettext" # for envsubst
  )

  # Iterate over each dependency
  for dep in "${DEPENDENCIES[@]}"; do
    # Split the dependency string into an array using '|' as the delimiter
    IFS='|' read -ra PKG_ALTERNATIVES <<<"$dep"

    # Flag to check if the package has been installed
    INSTALLED=false

    # Iterate over each alternative package name
    for pkg in "${PKG_ALTERNATIVES[@]}"; do
      # Check if the package is already installed
      if command_exists "$pkg"; then
        echo "✔️  '$pkg' is already installed."
        INSTALLED=true
        break
      fi

      # Attempt to install the package
      echo "➜  Attempting to install '$pkg'..."
      if $INSTALL_CMD "$pkg" >/dev/null 2>&1; then
        echo "✔️  '$pkg' installed successfully."
        INSTALLED=true
        break
      else
        echo "⚠️  Failed to install '$pkg'. Trying next alternative..."
      fi
    done

    # If none of the alternatives were installed, log a warning and exit
    if [ "$INSTALLED" = false ]; then
      echo "⚠️  Warning: Could not install any of the alternatives for '$dep'. Please install it manually if required."
      exit 1
    fi
  done
}

# Function to create the base image
create_base_image() {
  echo "Base image not found. Creating it ..."

  if [[ ! -f "${BASE_IMAGE_PATH}" ]]; then
    wget "${DEBIAN_URL}" --output-document "${BASE_IMAGE_PATH}.tmp"
    echo "${IMAGE_SHA512}  ${BASE_IMAGE_PATH}.tmp" | sha512sum -c -
    mv "${BASE_IMAGE_PATH}.tmp" "${BASE_IMAGE_PATH}"
  else
    echo "Base image found at $BASE_IMAGE_PATH"
  fi

  echo "Base image created at $BASE_IMAGE_PATH"
}

# Generate cloud-init file
create_cloud_init_file() {
  # Path to the secrets file
  SECRET_ENV_FILE="../private/secret_env.sh"

  # Check if the secrets file exists
  if [[ ! -f $SECRET_ENV_FILE ]]; then
    echo "Error: $SECRET_ENV_FILE not found."
    echo "The file should contain the public SSH key as an environment variable, e.g., SSH_PUB_KEY='ssh-rsa AAAAB3...'"
    exit 1
  fi

  # Source the secrets file
  source $SECRET_ENV_FILE

  # Check if the SSH_PUB_KEY variable is set
  if [[ -z "${SSH_PUB_KEY}" ]]; then
    echo "Error: SSH_PUB_KEY is not set in $SECRET_ENV_FILE."
    echo "The file should include a line like: SSH_PUB_KEY='ssh-rsa AAAAB3...'"
    exit 1
  fi

  # Check if the cloud-init template file exists
  if [[ ! -f ${VM_CLOUD_INIT_TEMPLATE} ]]; then
    echo "Error: Cloud-init template file ${VM_CLOUD_INIT_TEMPLATE} not found."
    exit 1
  fi

  # Generate the cloud-init file
  envsubst < "${VM_CLOUD_INIT_TEMPLATE}" > "${VM_CLOUD_INIT}"
  echo "Cloud-init file ${VM_CLOUD_INIT} has been generated successfully."
}

create_net_bridge() {
  # Check if the bridge already exists
  if ip link show "$BRIDGE_NAME" > /dev/null 2>&1; then
      echo "Bridge $BRIDGE_NAME already exists. No action required."
      return
  fi

  # Create the bridge interface
  echo "Creating bridge $BRIDGE_NAME..."
  sudo ip link add name "$BRIDGE_NAME" type bridge
  if [[ $? -ne 0 ]]; then
      echo "Error: Failed to create bridge $BRIDGE_NAME."
      exit 1
  fi

  # Bring up the bridge and the physical interface
  echo "Bringing up the bridge and physical interface..."
  sudo ip link set "$BRIDGE_NAME" up

  echo "Bridge $BRIDGE_NAME has been successfully created."

}

# Detect Linux distribution and set package manager
detect_distro

# Install dependencies
install_dependencies

create_cloud_init_file

create_net_bridge

# Check if the base image exists; if not, create it
if [[ ! -f "$BASE_IMAGE_PATH" ]]; then
  create_base_image
else
  echo "Base image found at $BASE_IMAGE_PATH"
fi

# Check if VM already exists
if virsh dominfo "$VM_NAME" &>/dev/null; then
  echo "Error: VM '$VM_NAME' already exists. To recreate it, please destroy the existing VM first."
  echo "Use the following commands to destroy and undefine the VM:"
  echo "  virsh destroy '$VM_NAME'"
  echo "  virsh undefine '$VM_NAME'"
  exit 1
fi

# Create a copy of the base image for the new VM
echo "Creating VM image..."
sudo cp "$BASE_IMAGE_PATH" "$IMAGE_STORAGE_PATH"

# Define the new VM using virt-install
echo "Defining and creating the VM..."

virt-install \
  --name "$VM_NAME" \
  --memory "$RAM_MB" \
  --memorybacking=source.type=memfd,access.mode=shared \
  --vcpus "$VCPUS" \
  --disk path="$IMAGE_STORAGE_PATH",format=qcow2 \
  --os-variant debian12 \
  --virt-type kvm \
  --network network="$NETWORK",model=virtio \
  --network bridge=${BRIDGE_NAME},model=virtio \
  --filesystem source=$(realpath ../ansible),target=ansible-folder,type=mount,driver.type=virtiofs \
  --cloud-init user-data="${VM_CLOUD_INIT}" \
  --import \
  --graphics none \
  --console pty,target_type=serial \
  --noautoconsole \
  --quiet

echo "VM '$VM_NAME' is booting. Waiting for configuration to complete..."

# Loop to check if the VM exists and Cloud-Init has finished
while true; do
  # Check if the VM exists
  if ! virsh domstate "$VM_NAME" >/dev/null 2>&1; then
    echo -e "\nError: VM '$VM_NAME' no longer exists or has been removed."
    exit 1
  fi

  # Check if Cloud-Init has finished
  if virsh qemu-agent-command "$VM_NAME" '{"execute":"guest-file-open","arguments":{"path":"/var/lib/cloud/instance/boot-finished","mode":"r"}}' >/dev/null 2>&1; then
    echo -e "\nVM '$VM_NAME' has been successfully created and configured."
    break
  fi

  # Continue waiting
  echo -n "."
  sleep 20
done

virsh domifaddr ${VM_NAME}

echo -e "\nVM '$VM_NAME' has been successfully created and configured."

