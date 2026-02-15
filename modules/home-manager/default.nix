{ pkgs, inputs, ... }:

{
  home.username = "steve";
  home.homeDirectory = "/home/steve";

  home.packages = with pkgs; [
    thunderbird
    firefox
    google-chrome
    vscode
    spotify
    bitwarden-desktop
    podman-desktop
    loupe
    usbutils
    # Steam is installed system-wide for udev rules, but we can add utils here if needed.

    # Ghostty
    inputs.ghostty.packages.${pkgs.system}.default
    gemini-cli
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
      enable-hot-corners = false;
    };

    "org/gnome/shell/extensions/dash-to-dock" = {
      dock-position = "BOTTOM";
      height-fraction = 0.9;
    };

    "org/gnome/mutter" = {
      experimental-features = ["scale-monitor-framebuffer"];
      workspaces-only-on-primary = false;
    };

    "org/gnome/settings-daemon/plugins/color" = {
      night-light-enabled = true;
      night-light-schedule-automatic = false; # Set to true for sunset-to-sunrise
      night-light-schedule-from = 22.0;
      night-light-schedule-to = 6.0;
      night-light-temperature = 4000; # A value in Kelvin, e.g., 4000
    };

    "org/gnome/desktop/interface" = {
      show-battery-percentage = true;
    };

    "org/gnome/desktop/peripherals/touchpad" = {
      natural-scroll = false;
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name  = "Steffen";
        email = "steven@posteo.de";
      };
      init.defaultBranch = "main";
    };
  };

  programs.home-manager.enable = true;

  home.stateVersion = "25.11";
}
