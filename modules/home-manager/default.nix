{ pkgs, inputs, settings, ... }:

{
  imports = [ ./kde-settings.nix ];

  home.username = settings.username;
  home.homeDirectory = "/home/${settings.username}";

  home.packages = with pkgs; [
    thunderbird
    firefox
    google-chrome
    vscode
    spotify
    podman-desktop
    kdePackages.gwenview
    usbutils
    # Steam is installed system-wide for udev rules, but we can add utils here if needed.
    inputs.ghostty.packages.${pkgs.stdenv.hostPlatform.system}.default
    gemini-cli
    signal-desktop
    trayscale
    nextcloud-client
    zellij # terminal multiplexer
    claude-code
  ];

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
