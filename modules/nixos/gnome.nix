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
    gnomeExtensions.compiz-windows-effect # wiggly
    # gnomeExtensions.ding # desktop icons ng
    # gnomeExtensions.search-light # Search Light might not be packaged in nixpkgs yet.
    gnomeExtensions.battery-health-charging
  ];

  # Remove default packages
  environment.gnome.excludePackages = (with pkgs; [
    cheese
    gnome-music
    gnome-terminal
    geary
    evince
    totem
  ]);

  programs.dconf.enable = true;

  services.udev.packages = with pkgs; [ gnome-settings-daemon ];
}
