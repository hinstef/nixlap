{ pkgs, inputs, settings, ... }:

{
  home.username = settings.username;
  home.homeDirectory = "/home/${settings.username}";

  home.packages = with pkgs; [
    thunderbird
    firefox
    google-chrome
    vscode
    spotify
    podman-desktop
    loupe
    usbutils
    # Steam is installed system-wide for udev rules, but we can add utils here if needed.
    inputs.ghostty.packages.${pkgs.system}.default
    gemini-cli
    signal-desktop
    tail-tray
    nextcloud-client
    bitwarden-desktop
    zellij # terminal multiplexer
    claude-code
  ];

  dconf.settings = {
    "org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [
        "dash-to-dock@micxgx.gmail.com"
        "blur-my-shell@aunetx"
        "caffeine@patapon.info"
        "compiz-windows-effect@hermes83.github.com"
        "battery-health-charging@maniacx.github.com"
        "no-overview@fthx"
        "hibernate-status@dromi"
        "search-light@icedman.github.com"
        "appindicatorsupport@rgcjonas.gmail.com"
      ];
    };

    "org/gnome/shell/extensions/dash-to-dock" = {
      dock-position = "LEFT";
      height-fraction = 1.0;
      extend-height = true;
      dock-fixed = true;
      custom-theme-customize-dash = true;
      force-straight-corner = true;
    };

    "org/gnome/shell/extensions/blur-my-shell" = {
      settings-version = 2;
    };

    "org/gnome/shell/extensions/blur-my-shell/appfolder" = {
      brightness = 0.6;
      sigma = 30;
    };

    "org/gnome/shell/extensions/blur-my-shell/coverflow-alt-tab" = {
      pipeline = "pipeline_default";
    };

    "org/gnome/shell/extensions/blur-my-shell/dash-to-dock" = {
      blur = true;
      brightness = 0.6;
      override-background = true;
      pipeline = "pipeline_default_rounded";
      sigma = 30;
      static-blur = false;
      style-dash-to-dock = 0;
    };

    "org/gnome/shell/extensions/blur-my-shell/lockscreen" = {
      pipeline = "pipeline_default";
    };

    "org/gnome/shell/extensions/blur-my-shell/overview" = {
      pipeline = "pipeline_default";
    };

    "org/gnome/shell/extensions/blur-my-shell/panel" = {
      brightness = 0.6;
      pipeline = "pipeline_default";
      sigma = 30;
    };

    "org/gnome/shell/extensions/blur-my-shell/screenshot" = {
      pipeline = "pipeline_default";
    };

    "org/gnome/shell/extensions/blur-my-shell/window-list" = {
      brightness = 0.6;
      sigma = 30;
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
      enable-hot-corners = false;
    };

    "org/gnome/desktop/peripherals/touchpad" = {
      natural-scroll = false;
    };
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
