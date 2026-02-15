{ pkgs, inputs, ... }:

{
  home.username = "user";
  home.homeDirectory = "/home/user";

  home.packages = with pkgs; [
    thunderbird
    firefox
    google-chrome
    vscode
    spotify
    bitwarden
    podman-desktop
    loupe
    # Steam is installed system-wide for udev rules, but we can add utils here if needed.

    # Ghostty
    inputs.ghostty.packages.${pkgs.system}.default
  ];

  dconf.settings = {
    "org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [
        "dash-to-dock@micxgx.gmail.com"
        "blur-my-shell@aunetx"
        "caffeine@patapon.info"
        "compiz-windows-effect@hermes83.github.com"
        "ding@rastersoft.com"
        "battery-health-charging@maniacx.github.com"
      ];
    };

    "org/gnome/shell/extensions/dash-to-dock" = {
      dock-position = "BOTTOM";
      height-fraction = 0.9;
    };
  };

  programs.git = {
    enable = true;
    userName = "Your Name";
    userEmail = "your.email@example.com";
  };

  programs.home-manager.enable = true;

  home.stateVersion = "25.11";
}
