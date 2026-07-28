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

  # Backtraces for the recurring cosmic-panel exit-101 panics; only emits on crash.
  environment.sessionVariables.RUST_BACKTRACE = "1";

  services.libinput.touchpad = {
    naturalScrolling = false;
    scrollMethod = "twofinger";
  };
}
