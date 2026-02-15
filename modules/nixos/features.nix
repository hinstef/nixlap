{ pkgs, lib, ... }:

{
  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Kernel
  boot.kernelPackages = pkgs.linuxPackages_zen;
  boot.kernelParams = [ "3417344>" ];
  boot.resumeDevice = "/dev/mapper/cryptroot";

  # Splash screen
  boot.plymouth.enable = true;

  hardware.enableAllFirmware = true;

  # Initrd systemd for TPM unlock
  boot.initrd.systemd.enable = true;

  # NOTE: The LUKS device name "cryptroot" must match what is defined in your hardware-configuration.nix or manual configuration.
  # To enable TPM unlock, you must run: 
  # `sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2 /dev/disk/by-uuid/7ae6a202-43e4-40a7-a336-f01f26426fbd`
  boot.initrd.luks.devices."cryptroot".crypttabExtraOpts = [ "tpm2-device=auto" ];
  # We comment it out by default to avoid errors if the device name differs, but the user should uncomment and adjust it.

  # Btrfs scrubbing
  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
    fileSystems = [ "/" ];
  };

  # Fingerprint reader
  services.fprintd.enable = true;
  # Uncomment the following lines if your fingerprint reader requires a specific TOD driver.
  # You might need to identify your fingerprint reader's model and search for the corresponding Nixpkgs driver.
  # services.fprintd.tod.enable = true;
  # services.fprintd.tod.driver = pkgs.libfprint-2-tod1-goodix-550a; # Example for Goodix driver
  # services.fprintd.tod.driver = pkgs.libfprint-2-tod1-vfs0090; # Example for vfs0090 driver
  security.pam.services.gdm-password.fprintAuth = true;
      security.pam.services.sudo.fprintAuth = true;
      security.pam.services.login.fprintAuth = lib.mkForce true;
  
  # Power management & Hibernation
  powerManagement.enable = true;

  services.logind = {
    settings.Login = {
      HandlePowerKey = "suspend-then-hibernate";
      HandleLidSwitch = "suspend-then-hibernate";
    };
  };

  systemd.sleep.extraConfig = ''
    HibernateDelaySec=45min
  '';

  # NOTE: For hibernation to work, you need a swap partition or swapfile large enough to hold RAM.
  # You also need to set `boot.resumeDevice` and `boot.kernelParams` (resume_offset if using swapfile).

  # Instructions for creating a swapfile on Btrfs:
  # 1. sudo btrfs filesystem mkswapfile --size 16G --uuid clear /swapfile
  #    (This command automatically handles NOCOW and other Btrfs requirements)
  # 2. Add the following to your configuration:
  #    swapDevices = [ { device = "/swapfile"; } ];
  # 3. Find the offset:
  #    sudo btrfs inspect-internal map-swapfile -r /swapfile
  # 4. Set boot params:
  #    boot.kernelParams = [ "resume_offset=<offset_from_step_3>" ];
  #    boot.resumeDevice = "/dev/mapper/cryptroot"; # Or your root device
}
