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
mkpasswd -m yescrypt         # new login hash -> <username>-password
```

The login-password key must be named `<username>-password`; `modules/nixos/secrets.nix`
derives it from `settings.username` rather than hardcoding it.

## Build

```bash
nix flake check                                                          # build check, no sudo
sudo nixos-rebuild switch --flake .#$(hostname)
```

The flake output is named after `settings.hostname`, so it is whatever you set.
`checks` builds the host's `system.build.toplevel`, so `nix flake check` is a full
build, not just an eval.

Note `nix flake check` and `.#` read the *committed* tree and ignore untracked
files — a new module is invisible to them until at least `git add -N`.

## Updates are deliberate

There is no `system.autoUpgrade`. It was removed on purpose:

- With `upgrade = false` it never touched `flake.lock`, so it could not pull a
  security patch — packages only move on a manual `nix flake update`. Its only
  real job was re-applying local edits overnight, and on most nights it rebuilt
  to the store path that was already current.
- It gave an unattended root job a build of `settings.flakeDir`, a directory the
  login user can write. A NixOS activation script runs as root, so anything able
  to write there — a bad postinstall, a browser exploit, one of the agents that
  edit this repo by design — got root on a timer, unprompted.

Removing it is not a defence against a compromised account: `nixadmin-helper`
still switches on request. It removes the *unattended* path, so root activation
now follows something a human actually started.

To update:

```bash
nix flake update          # move nixpkgs et al; commit the lock
nix flake check           # full build of the new closure
sudo nixos-rebuild switch --flake .#$(hostname)
```

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
