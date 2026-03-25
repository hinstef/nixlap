{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    kdePackages.partitionmanager
  ];

  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.desktopManager.plasma6.enable = true;

  services.libinput.touchpad.naturalScrolling = false;
}
