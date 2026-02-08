{ pkgs, ... }:

{
  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Kernel
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # Splash screen
  boot.plymouth.enable = true;

  # Initrd systemd for TPM unlock
  boot.initrd.systemd.enable = true;

  # NOTE: The LUKS device name "cryptroot" must match what is defined in your hardware-configuration.nix or manual configuration.
  # To enable TPM unlock, you must run: `systemd-cryptenroll --tpm2-device=auto --tpm2-pcr=0+2 /dev/your-encrypted-partition`
  # boot.initrd.luks.devices."cryptroot".crypttabExtraOpts = [ "tpm2-device=auto" ];
  # We comment it out by default to avoid errors if the device name differs, but the user should uncomment and adjust it.

  # Btrfs scrubbing
  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
    fileSystems = [ "/" ];
  };

  # Fingerprint reader
  services.fprintd.enable = true;

  # Power management & Hibernation
  powerManagement.enable = true;

  services.logind = {
    lidSwitch = "suspend-then-hibernate";
    extraConfig = ''
      HandlePowerKey=suspend-then-hibernate
    '';
  };

  systemd.sleep.extraConfig = ''
    HibernateDelaySec=45min
  '';

  # NOTE: For hibernation to work, you need a swap partition or swapfile large enough to hold RAM.
  # You also need to set `boot.resumeDevice` and `boot.kernelParams` (resume_offset if using swapfile).
}
