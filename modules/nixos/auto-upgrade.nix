{ config, lib, settings, ... }:

{
  # Rebuilds from the working tree, NOT from inputs.self.outPath — that is a store
  # copy frozen at the last manual switch, so nightly runs used to drift ahead of
  # the repo and any later repo-driven switch silently rolled the system back.
  # The path: prefix bypasses nix's git-ownership check for root, as nixadmin-helper
  # does. It also means nix copies the directory verbatim, uncommitted edits and
  # all — that is deliberate: work in progress is meant to go out tonight.
  #
  # No --update-input / upgrade here on purpose: it would have this root job
  # rewrite flake.lock in a user-owned repo. Move nixpkgs with `nix flake update`.
  system.autoUpgrade = {
    enable = true;
    flake = "path:${settings.flakeDir}";
    # The module appends --upgrade unless this is false, and nixos-rebuild-ng
    # turns that into a `nix flake update nixpkgs` -- i.e. root rewriting the
    # lock in a user-owned repo, which is what this whole arrangement avoids.
    upgrade = false;
    flags = [ "-L" ]; # print build logs
    dates = "02:00";
    randomizedDelaySec = "45min";
    # persistent = true is the module default, so a laptop that was off or asleep
    # at 02:00 runs the missed upgrade shortly after it next boots, rather than
    # skipping the day. Left implicit; documented here so nobody "fixes" it.
  };

  # Build the flake's checks before anything touches the running system. Same
  # path: ref as the switch itself, so this gates on the exact tree about to be
  # activated, uncommitted edits included — and it is the same derivation, so the
  # switch reuses it from the store instead of building twice. A broken tree fails
  # here and the system is left alone.
  # --no-write-lock-file keeps this root job from rewriting a user-owned lock.
  systemd.services.nixos-upgrade.serviceConfig.ExecStartPre =
    "${lib.getExe' config.nix.package "nix"} flake check --no-write-lock-file path:${settings.flakeDir}";
}
