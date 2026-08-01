{ pkgs, config, inputs, settings, ... }:

{
  imports = [
    "${inputs.private}/hardware-configuration.nix"
    ../../modules/nixos/cosmic.nix
    ../../modules/nixos/common.nix
    ../../modules/nixos/flatpak.nix
    ../../modules/nixos/secrets.nix
    # The nixadmin module comes from the nixadmin flake input (see flake.nix).
  ];

  services.nixadmin = {
    enable       = true;
    user         = settings.username;
    flakeDir     = "/home/${settings.username}/workspace/nixlap";
    hostname     = settings.hostname;
    defaultChain = "local";          # local chain is proven; remote needs Hermes/API
    local.model  = "qwen2.5:3b";
    # Extra modules (system, power, performance, bluetooth, updates, security)
    # discovered via entry points from the nixadmin-extras package.
    extraModules = [ inputs.nixadmin.packages.${pkgs.stdenv.hostPlatform.system}.nixadmin-extras ];
    # remote.model = "claude-sonnet-4-5";  # used once a Hermes proxy / API base is set
    # remote.base  = "http://localhost:4000";
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
    # Never `hashedPassword` from a nix value — that lands world-readable (0444)
    # in /nix/store via users-groups.json. sops decrypts to /run/secrets-for-users.
    hashedPasswordFile = config.sops.secrets.steve-password.path;
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
