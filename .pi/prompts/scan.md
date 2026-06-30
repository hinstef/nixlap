---
description: Scan the NixOS config and summarise the current system state
---

Read the following files and give a concise summary of the current system:
- `hosts/laptop/default.nix`
- `modules/nixos/common.nix`
- `modules/nixos/kde.nix`
- `modules/home-manager/default.nix`
- `modules/nixos/flatpak.nix`

Also run `flatpak list --app --columns=name,application` to get currently installed Flatpaks.

Summarise:
1. Installed user packages (home.packages)
2. Key system configuration (kernel, display manager, notable services)
3. Installed Flatpaks
4. Any obvious todos or open issues (check `todo.md`)
