{ pkgs, lib, settings, ... }:

{
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

  # Fingerprint reader
  services.fprintd.enable = true;

  security.pam.services.sddm.fprintAuth = true;
  security.pam.services.sudo.fprintAuth = true;
  security.pam.services.login.fprintAuth = true;

  # Polkit
  security.polkit.enable = true;

  # Power management
  powerManagement.enable = true;
  services.power-profiles-daemon.enable = true;

  services.logind.settings.Login = {
    HandlePowerKey = if settings.hibernate then "suspend-then-hibernate" else "suspend";
    HandleLidSwitch = if settings.hibernate then "suspend-then-hibernate" else "suspend";
    HandleLidSwitchExternalPower = if settings.hibernate then "suspend-then-hibernate" else "suspend";
    LidSwitchIgnoreInhibited = "yes";
  };

  systemd.sleep.settings.Sleep = lib.mkIf settings.hibernate {
    HibernateDelaySec = "45min";
    SuspendEstimationSec = "60min";
  };

  services.tailscale.enable = true;
  services.fwupd.enable = true;

  programs.nix-ld.enable = true;

  # Automatically adjusts process nice levels and scheduling for known apps,
  # keeps the desktop responsive when something CPU-hungry runs in the background.
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
  };

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
