{ pkgs, lib, settings, ... }:

let
  # What the lid and the power key do. Hibernating without a swapfile just fails,
  # so this falls back to plain suspend unless settings.hibernate is set.
  sleepAction = if settings.hibernate then "suspend-then-hibernate" else "suspend";
in
{
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Nightly upgrades live in modules/nixos/auto-upgrade.nix.

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10; # Prevent /boot from filling up
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_zen;
  boot.kernelParams = [ "amd_pstate=active" ] ++ lib.optionals settings.hibernate [ "resume_offset=${settings.resumeOffset}" ];
  boot.resumeDevice = lib.mkIf settings.hibernate settings.resumeDevice;

  # Splash screen
  boot.plymouth.enable = true;

  hardware.enableAllFirmware = true;

  # Switches from scripted initrd to systemd-based initrd (required for TPM2 unlock)
  boot.initrd.systemd.enable = true;

  # TPM unlock for LUKS — to set up, run:
  # sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2 /dev/disk/by-uuid/<YOUR-LUKS-UUID>
  # Find your UUID with: blkid | grep crypto_LUKS
  boot.initrd.luks.devices."cryptroot".crypttabExtraOpts = [ "tpm2-device=auto" ];

  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
    fileSystems = [ "/" ];
  };

  # Fingerprint reader. security.pam.services.*.fprintAuth already defaults to
  # services.fprintd.enable, so sudo/login/greeter need no per-service opt-in —
  # only deviations from that default are worth writing down (see cosmic.nix).
  services.fprintd.enable = true;

  # Polkit
  security.polkit.enable = true;

  # Power management
  powerManagement.enable = true;
  services.power-profiles-daemon.enable = true;

  services.logind.settings.Login = {
    HandlePowerKey = sleepAction;
    HandleLidSwitch = sleepAction;
    HandleLidSwitchExternalPower = sleepAction;
    LidSwitchIgnoreInhibited = "yes";
  };

  systemd.sleep.settings.Sleep = lib.mkIf settings.hibernate {
    HibernateDelaySec = "45min";
    SuspendEstimationSec = "60min";
  };

  fonts.packages = with pkgs.nerd-fonts; [ jetbrains-mono ];

  services.tailscale.enable = true;
  services.fwupd.enable = true;

  programs.nix-ld.enable = true;

  # Distributes hardware interrupts across CPU cores, prevents one core from
  # handling all I/O on multi-core AMD systems.
  services.irqbalance.enable = true;

  # NOTE: For hibernation to work, you need a swap partition or swapfile large enough to hold RAM.
  # You also need to set `boot.resumeDevice` and `boot.kernelParams` (resume_offset if using swapfile).

  # Instructions for creating a swapfile on Btrfs:
  # 1. sudo btrfs filesystem mkswapfile --size 16G --uuid clear /swapfile
  #    (This command automatically handles NOCOW and other Btrfs requirements)
  # 2. Add the following to your configuration:
  #    swapDevices = [ { device = "/swapfile"; } ];
  # 3. Find the offset:
  #    sudo btrfs inspect-internal map-swapfile -r /swapfile
  # 4. Set resumeOffset in settings.nix to the value from step 3
  # 5. Set hibernate = true in settings.nix
  # 6. Reboot & test with: sudo systemctl hibernate

  swapDevices = lib.mkIf settings.hibernate [ { device = "/swapfile"; } ];
}
