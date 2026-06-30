{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    kdePackages.partitionmanager
  ];

  services.displayManager.plasma-login-manager.enable = true;
  services.desktopManager.plasma6.enable = true;

  services.libinput.touchpad.naturalScrolling = false;
}
