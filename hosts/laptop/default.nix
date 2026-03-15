{ pkgs, inputs, settings, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/gnome.nix
    ../../modules/nixos/features.nix
    ../../modules/nixos/flatpak.nix
    ../../modules/nixos/secrets.nix
  ];

  networking.hostName = settings.hostname;

  time.timeZone = settings.timezone;

  i18n.defaultLocale = settings.locale;

  users.users.${settings.username} = {
    isNormalUser = true;
    description = settings.fullName;
    extraGroups = [ "networkmanager" "wheel" "video" "input" ];
    shell = pkgs.bash;
    hashedPassword = settings.hashedPassword;
  };

  # Enable Home Manager
  home-manager = {
    extraSpecialArgs = { inherit inputs settings; };
    users.${settings.username} = import ../../modules/home-manager/default.nix;
    useGlobalPkgs = true;
    useUserPackages = true;
  };

  # Enable Steam
  programs.steam.enable = true;
  programs.steam.gamescopeSession.enable = true;

  # Enable Podman
  virtualisation.podman.enable = true;

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

  # Auto upgrade
  system.autoUpgrade = {
    enable = true;
    flake = inputs.self.outPath;
    flags = [
      "--update-input"
      "nixpkgs"
      "-L" # print build logs
    ];
    dates = "02:00";
    randomizedDelaySec = "45min";
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
    settings = {
      General = {
        # Shows battery charge of connected devices on supported
        Experimental = true;
        # When enabled other devices can connect faster to us, however
        # the tradeoff is increased power consumption.
        FastConnectable = false;
      };
      Policy = {
        # Enable all controllers when they are found. This includes
        # adapters present on start as well as adapters that are plugged
        # in later on. Defaults to 'true'.
        AutoEnable = true;
      };
    };
  };

  # WARNING: Do NOT change this. It is NOT your NixOS version — it controls backward compatibility.
  # See: https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.11";
}
