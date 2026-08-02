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

## Nightly upgrades

`modules/nixos/auto-upgrade.nix` rebuilds at 02:00 (+ up to 45 min jitter) from the
working tree at `settings.flakeDir`, not from a flake input. The `path:` ref copies
the directory verbatim, so **uncommitted edits are picked up and switched to** —
that is intended, not an oversight.

`ExecStartPre` runs `nix flake check` against that same `path:` ref first, so the
gate covers the exact tree about to be activated, work in progress included. If it
does not build, the unit fails and the running system is left untouched. It is the
same derivation the switch then reuses from the store, so it costs nothing beyond
the build that was going to happen anyway.

Missed runs are not lost: `system.autoUpgrade.persistent` defaults to true, so a
laptop that was off or asleep at 02:00 runs the upgrade shortly after it next boots.
There is no AC-power condition — it runs on battery too.

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
