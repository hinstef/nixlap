{ pkgs, ... }:

{
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.wayland = true;
  services.desktopManager.gnome.enable = true;

  environment.systemPackages = with pkgs; [
    gnomeExtensions.dash-to-dock
    gnomeExtensions.blur-my-shell
    gnomeExtensions.caffeine
    gnomeExtensions.gtk4-desktop-icons-ng-ding
    gnomeExtensions.no-overview
    gnomeExtensions.search-light
    gnomeExtensions.battery-health-charging
    gnomeExtensions.hibernate-status-button
    gnomeExtensions.appindicator
    refine
    gnome-tweaks
  ];

  # Remove default packages
  environment.gnome.excludePackages = (with pkgs; [
    cheese
    gnome-music
    gnome-terminal
    gnome-initial-setup
    geary
    evince
    totem
  ]);

  # Spacebar file previewer in Nautilus
  services.gnome.sushi.enable = true;

  programs.dconf.enable = true;

  services.udev.packages = with pkgs; [ gnome-settings-daemon ];
}
