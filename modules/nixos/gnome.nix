{ pkgs, ... }:

{
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.displayManager.gdm.wayland = true;
  services.xserver.desktopManager.gnome.enable = true;

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
#  environment.gnome.excludePackages = (with pkgs; [
#    gnome-photos
#    gnome-tour
#    gedit
#    cheese
#  ]) ++ (with pkgs.gnome; [
    # cheese
#    gnome-music
#    gnome-terminal
#    epiphany
#    geary
#    evince
#    gnome-characters
#    totem
#    tali
#    iagno
#    hitori
#    atomix
#  ]);

  programs.dconf.enable = true;

  services.udev.packages = with pkgs; [ gnome-settings-daemon ];
}
