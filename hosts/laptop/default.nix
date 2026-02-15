{ pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/gnome.nix
    ../../modules/nixos/features.nix
    ../../modules/nixos/flatpak.nix
    ../../modules/nixos/secrets.nix
  ];

  networking.hostName = "laptop"; # Define your hostname.

  # Set your time zone.
  time.timeZone = "UTC";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.steve = {
    isNormalUser = true;
    description = "User";
    extraGroups = [ "networkmanager" "wheel" "video" "input" ];
    shell = pkgs.bash;
    hashedPassword = "$y$j9T$CrhuM.WqguUcJRHwoQ8hw/$fuffjxq4ayK3G82VvK4qem5N821pR123gpRE9tXxcy.";

  };

  # Enable Home Manager
  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    users.steve = import ../../modules/home-manager/default.nix;
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

  system.stateVersion = "25.11";
}
