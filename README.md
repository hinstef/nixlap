# NixOS Laptop Configuration

This is a modular, flake-based NixOS configuration for a laptop, featuring Gnome Wayland, Btrfs with encryption, TPM auto-unlock, and modern apps.

## Features

- **Desktop**: Gnome (Wayland) with various extensions (Dash to Dock, Blur my Shell, etc.).
- **Filesystem**: Btrfs with background scrubbing and compression.
- **Security**: Full disk encryption (LUKS) with TPM2 auto-unlock and Fingerprint reader support.
- **Apps**: Firefox, Chrome, VSCode, Spotify, Bitwarden, Ghostty, Steam, etc.
- **Management**: Home Manager, Flakes, Auto-upgrades, Garbage collection.
- **Secrets**: Managed via sops-nix.

## Installation Guide

### 1. Partitioning and Encryption

Boot into the NixOS Live ISO.

Partition your disk (assume `/dev/nvme0n1`):
- 512MB FAT32 for Boot (`/boot`)
- Rest for LUKS encrypted partition

```bash
# Example partitioning (use cfdisk or gdisk)
cfdisk /dev/nvme0n1
# Create 512M EFI partition (type EF00)
# Create Linux Filesystem partition for the rest (type 8300)

# Format Boot
mkfs.vfat -F32 -n boot /dev/nvme0n1p1

# Encrypt Root
cryptsetup luksFormat /dev/nvme0n1p2
cryptsetup open /dev/nvme0n1p2 cryptroot

# Format Btrfs
mkfs.btrfs -L nixos /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt

# Create Subvolumes (optional but recommended)
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@log
umount /mnt

# Mount Subvolumes
mount -o compress=zstd,subvol=@ /dev/mapper/cryptroot /mnt
mkdir -p /mnt/{boot,home,nix,var/log}
mount -o compress=zstd,subvol=@home /dev/mapper/cryptroot /mnt/home
mount -o compress=zstd,subvol=@nix /dev/mapper/cryptroot /mnt/nix
mount -o compress=zstd,subvol=@log /dev/mapper/cryptroot /mnt/var/log
mount /dev/nvme0n1p1 /mnt/boot
```

### 2. Generate Hardware Config

```bash
nixos-generate-config --root /mnt --show-hardware-config > hosts/laptop/hardware-configuration.nix
```

Review `hosts/laptop/hardware-configuration.nix` to ensure filesystems are correct.

### 3. Install

You can install directly from the remote repository.

**Option A: Local Clone (Recommended for customization)**
Copy this flake to `/mnt/etc/nixos` (or clone it there).

```bash
cd /mnt/etc/nixos
nixos-install --flake .#laptop
```

**Option B: Remote Install**
Install directly from GitHub (replace `username/repo` with your actual repository details).
*Note: You still need to generate and copy the hardware-configuration.nix into the flake structure if you do this, or ensure the remote flake handles your hardware.*

Since the hardware configuration is machine-specific, the recommended approach is to clone the repo to `/mnt/etc/nixos`, generate the hardware config there, and then install.

```bash
# Clone to /mnt/etc/nixos
git clone https://github.com/username/repo /mnt/etc/nixos
# Generate hardware config
nixos-generate-config --root /mnt --show-hardware-config > /mnt/etc/nixos/hosts/laptop/hardware-configuration.nix
# Install
nixos-install --flake /mnt/etc/nixos#laptop
```

### 4. Post-Install

Reboot into your new system.

#### TPM Auto-Unlock

To enable TPM auto-unlock for the encrypted disk:

1.  Ensure you have `boot.initrd.systemd.enable = true` (already enabled in `modules/nixos/features.nix`).
2.  Enroll the TPM key:

```bash
# Replace /dev/nvme0n1p2 with your encrypted partition
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcr=0+2 /dev/nvme0n1p2
```

3.  Uncomment the line in `modules/nixos/features.nix` or ensure your `hardware-configuration.nix` matches the crypttab settings. If you used `cryptroot` as the mapper name, you might need to add `crypttabExtraOpts` in `features.nix` or let `systemd-cryptenroll` handle it via slot.

#### Secrets with sops-nix

1.  Install `sops` and `age` (available in shell or install globally).
2.  Generate a key:
    ```bash
    sudo mkdir -p /var/lib/sops-nix
    sudo age-keygen -o /var/lib/sops-nix/key.txt
    ```
3.  Create/Edit secrets:
    ```bash
    sops secrets/secrets.yaml
    ```
4.  Uncomment sops configuration in `modules/nixos/secrets.nix`.

#### Fingerprint

Enroll fingerprint:
```bash
fprintd-enroll
```

#### Flatpaks

Flatpaks are managed declaratively in `modules/nixos/flatpak.nix`.
