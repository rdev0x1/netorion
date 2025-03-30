# VM Router Creation Script

This script automates the creation of a QEMU/KVM virtual machine that acts as a basic router. The VM is provisioned using cloud-init and includes an Ansible folder for further configuration.
I'm running it on musl version of void linux with amd64 architecture.

## Features
- Sets up a Debian-based VM with cloud-init.
- Shares an Ansible directory for configuration management.
- Automatically configures SSH with a user-provided public key.
- Includes a mechanism to ensure the VM is fully provisioned before signaling success.

## Prerequisites
1. Ensure you have the following installed on your host machine:
   - `virt-install`
   - `qemu-kvm`
   - `libvirt`
   - `cloud-init`
2. Add your SSH public key to `private/secret_env.sh`:

   ```bash
   export SSH_PUB_KEY="ssh-rsa AAAAB3...your-public-key"
   ```
3. Ensure you have sufficient permissions to manage VMs (e.g., be part of the `libvirt` group).

## Usage
1. Clone or download this repository.
2. Customize the following variables in the script as needed:
   - `VM_NAME`: The name of the VM.
   - `RAM_MB`: Amount of memory (in MB) allocated to the VM.
   - `VCPUS`: Number of virtual CPUs allocated to the VM.
   - `IMAGE_STORAGE_PATH`: Path to store the VM disk image.
   - `NETWORK` and `BRIDGE_NAME`: Networking configuration.
   - `VM_CLOUD_INIT`: Path to your cloud-init configuration file.
3. Source your `secret_env.sh` to load the SSH public key:

   ```bash
   source private/secret_env.sh
   ```

4. Run the script:

   ```bash
   ./create_vm_router.sh
   ```

Do not shut down your computer or terminate the script until it outputs a success message.

## What the Script Does
- Creates a Debian-based VM using QEMU/KVM.
- Configures the VM using the provided cloud-init configuration.
- Shares the `../ansible` directory inside the VM using `virtiofs`.
- Waits until the VM finishes provisioning before signaling completion.

## Troubleshooting
- If the VM does not appear to provision correctly, check its status using:

  ```bash
  virsh list --all
  virsh console <VM_NAME>
  ```

- Ensure `secret_env.sh` are correctly configured.

## Disclaimer
This script is for testing and experimentation purposes. It assumes basic knowledge of virtualization and Linux systems.
