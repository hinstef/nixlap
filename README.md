# NixOS Laptop Configuration

Flake-based NixOS config for a single laptop.

`flake.nix` and `hosts/laptop/default.nix` are the source of truth for what is
enabled. This file only covers what you cannot read off them.

## Private repo (required)

`settings.nix` and `hardware-configuration.nix` live in a separate repo, wired in
as the `private` input in `flake.nix`. Copy `settings.nix.example`, fill it in,
and point that input at your own repo.

Put nothing secret in it. Flake inputs are copied into `/nix/store` world-readable,
so "private on GitHub" is not "secret on the machine".

## Secrets

sops-nix. The age key is at `/var/lib/sops-nix/key.txt` (root, `0600`) — outside
git and outside the store. **Back it up**; without it a rebuild cannot decrypt
`secrets/`, and the login password comes from there.

```bash
sops secrets/users.yaml      # edit secrets
mkpasswd -m yescrypt         # new login hash -> steve-password
```

## Build

```bash
nix build .#nixosConfigurations.$(hostname).config.system.build.toplevel  # eval check, no sudo
sudo nixos-rebuild switch --flake .#$(hostname)
```

The flake output is named after `settings.hostname`, so it is whatever you set.

## Install

A normal NixOS install, except the config expects:

- a LUKS container named `cryptroot` (`modules/nixos/common.nix`)
- Btrfs subvolumes `@`, `@home`, `@nix`, `@log`, mounted with `compress=zstd`
- an EFI system partition at `/boot`

Generate `hardware-configuration.nix` into your private repo, then
`nixos-install --flake .#<hostname>`. Afterwards, to enroll the TPM:

```bash
systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2 /dev/<root-partition>
```

Set `system.stateVersion` and `home.stateVersion` to the release you install from.

## Hardware

AMD-specific: the zen kernel and `amd_pstate=active` in `modules/nixos/common.nix`.
