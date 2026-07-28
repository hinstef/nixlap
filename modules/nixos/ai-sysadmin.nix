{ config, lib, pkgs, ... }:

let
  cfg = config.services.aiSysAdmin;

  nixadmin = pkgs.writeShellApplication {
    name = "nixadmin";
    runtimeInputs = [
      (pkgs.python3.withPackages (ps: with ps; [
        httpx
        rich
        prompt-toolkit
      ]))
    ];
    text = ''
      export NIXADMIN_CONFIG_PATH="${cfg.configPath}"
      export NIXADMIN_MODEL="${cfg.model}"
      export NIXADMIN_AUTO_SNAPSHOT="${lib.boolToString cfg.enableAutoSnapshots}"
      exec python3 ${./ai-sysadmin/nixadmin.py} "$@"
    '';
  };

in {
  options.services.aiSysAdmin = {
    enable = lib.mkEnableOption "AI-powered NixOS system admin assistant";

    configPath = lib.mkOption {
      type = lib.types.str;
      default = "/home/steve/workspace/nixlap";
      description = "Path to the nixlap flake repository to read and edit.";
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "qwen2.5-coder:7b";
      description = "Ollama model to use for the assistant.";
    };

    rocmOverrideGfx = lib.mkOption {
      type = lib.types.str;
      default = "11.0.3";
      description = ''
        ROCm GFX version override. Required for AMD integrated graphics
        to be recognized by ROCm. 11.0.3 = RDNA3 iGPU (Radeon 780M/890M).
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "steve";
      description = "Username to add to the render group for GPU access.";
    };

    enableAutoSnapshots = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically create a git tag after every successful nixos-rebuild switch.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ollama with AMD GPU acceleration.
    # nixpkgs unstable ships separate derivations per backend;
    # ollama-rocm bundles the ROCm runtime for AMD GPU support.
    services.ollama = {
      enable = true;
      package = pkgs.ollama-rocm;
      # HSA_OVERRIDE_GFX_VERSION tells ROCm which GFX version to use —
      # required for iGPUs (e.g. Radeon 780M) not in ROCm's allowlist.
      environmentVariables = {
        HSA_OVERRIDE_GFX_VERSION = cfg.rocmOverrideGfx;
      };
    };

    # render group gives userspace access to GPU via /dev/dri/renderD*
    users.users.${cfg.user}.extraGroups = [ "render" ];

    # Model must be pulled manually once:  ollama pull <model>
    # nixadmin checks for the model at startup and prints instructions if missing.

    environment.systemPackages = [ nixadmin ];
  };
}
