{ pkgs, inputs, settings, ... }:

{
  imports = [ ./cosmic-settings.nix ];

  home.username = settings.username;
  home.homeDirectory = "/home/${settings.username}";

  # nixadmin-apps is deliberately absent: it comes from the nixadmin flake module
  # via environment.systemPackages, and a copy here shadowed it on PATH.
  # Steam is system-wide (hosts/laptop/default.nix) because it needs udev rules.
  home.packages = with pkgs; [
    # Desktop apps
    firefox
    google-chrome
    thunderbird
    signal-desktop
    telegram-desktop
    spotify
    nextcloud-client
    stirling-pdf-desktop
    rendercv

    # System tools
    mission-center
    gnome-disk-utility
    usbutils
    tree

    # Shell / editors
    vscode
    zellij # terminal multiplexer
    claude-code
    gemini-cli
    beads # bd — git-backed issue tracker
    inputs.nix-pi.packages.${pkgs.stdenv.hostPlatform.system}.default

    # Containers & Kubernetes
    podman-desktop
    podman-compose
    kubectl
    k9s
    kubernetes-helm

    # Python
    python3
    uv
    ruff

    # Data
    jq
  ];

  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [ "git" ];
    };
    plugins = [
      {
        name = "zsh-autosuggestions";
        src = pkgs.zsh-autosuggestions;
        file = "share/zsh-autosuggestions/zsh-autosuggestions.zsh";
      }
      {
        name = "zsh-syntax-highlighting";
        src = pkgs.zsh-syntax-highlighting;
        file = "share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";
      }
    ];
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name  = settings.fullName;
        email = settings.email;
      };
      init.defaultBranch = "main";
    };
  };

  programs.home-manager.enable = true;

  # WARNING: Do NOT change this. It is NOT your NixOS version — it controls backward compatibility.
  # See: https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "25.11";
}
