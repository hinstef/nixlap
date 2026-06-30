{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    cosmic-files
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;

  security.pam.services.cosmic-greeter.rules.auth.fprintd.args = [ "max-tries=3" ];

  services.system76-scheduler.enable = true;

  services.howdy = {
    enable = true;
    settings.video = {
      device_path = "/dev/video2";
      dark_threshold = 100;
    };
  };

  services.linux-enable-ir-emitter.enable = true;

  services.libinput.touchpad = {
    naturalScrolling = false;
    scrollMethod = "twofinger";
  };
}
