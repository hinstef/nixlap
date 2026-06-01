{ pkgs, inputs, settings, ... }:

{
  imports = [
    "${inputs.private}/hardware-configuration.nix"
    ../../modules/nixos/cosmic.nix
    ../../modules/nixos/common.nix
    ../../modules/nixos/flatpak.nix
    ../../modules/nixos/secrets.nix
    # ../../modules/nixos/ai-sysadmin.nix  # v1 — kept for reference, not imported
    # nixadmin module is now provided by the nixadmin flake input
  ];

  services.nixadmin = {
    enable   = true;
    user     = settings.username;
    flakeDir = "/home/${settings.username}/workspace/nixlap";
    hostname = settings.hostname;
    tier     = "local";           # "cloud" | "remote" | "local"
    local.model = "qwen3-tool:latest";
    # remote.baseUrl = "http://homeserver:11434/v1";
    # remote.model   = "llama3.3:70b";
    # cloud.model defaults to "claude-sonnet-4-5"
  };

  networking.hostName = settings.hostname;
  networking.networkmanager.enable = true;

  time.timeZone = settings.timezone;

  i18n.defaultLocale = settings.locale;

  users.users.root.hashedPassword = "!";

  users.users.${settings.username} = {
    isNormalUser = true;
    description = settings.fullName;
    extraGroups = [ "networkmanager" "wheel" "video" "input" ];
    shell = pkgs.zsh;
    hashedPassword = settings.hashedPassword;
  };

  # Enable Home Manager
  home-manager = {
    extraSpecialArgs = { inherit inputs settings; };
    users.${settings.username} = import ../../modules/home-manager/default.nix;
    useGlobalPkgs = true;
    useUserPackages = true;
  };

  programs.zsh.enable = true;

  # Enable Steam
  programs.steam.enable = true;
  programs.steam.gamescopeSession.enable = true;

  # Enable Podman
  virtualisation.podman.enable = true;

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
    };
  };

  # WARNING: Do NOT change this. It is NOT your NixOS version — it controls backward compatibility.
  # See: https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.11";
}
