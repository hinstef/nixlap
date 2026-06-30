##
## ollama-experiment.nix — isolated sandbox for tuning Ollama GPU offload.
##
## Runs a *second* ollama instance on a separate port so the main service
## (used by nixadmin) is never disturbed.
##
## Enable in hosts/laptop/default.nix:
##   services.ollamaExperiment.enable = true;
##
## Then test with:
##   OLLAMA_HOST=http://127.0.0.1:11435 ollama run gemma3:4b "hello"
##   journalctl -u ollama-experiment -f | grep -iE "gpu|layer|offload|error"
##
{ config, lib, pkgs, ... }:

let
  cfg = config.services.ollamaExperiment;

  # ── Package options ───────────────────────────────────────────────────────────
  #
  # Swap cfg.package in hosts/laptop/default.nix to try different builds:
  #
  #   pkgs.ollama-rocm   — ROCm backend (default nixpkgs build, gfx targets unknown)
  #   pkgs.ollama        — CPU + Vulkan backend (no ROCm, good baseline)
  #
  # Custom build with explicit gfx1103 target:
  #   The nixpkgs ollama-rocm is compiled against whatever AMDGPU_TARGETS
  #   the upstream ROCm derivations were built with. To force gfx1103 we
  #   override the rocmPackages scope that ollama-rocm depends on.
  #
  # ollama-rocm accepts rocmGpuTargets directly — it controls which GPU
  # architectures the bundled HIP/ggml backend is compiled for.
  # The default nixpkgs build reads targets from clr.localGpuTargets which
  # likely omits gfx1103 (Radeon 780M). Setting it explicitly here recompiles
  # only ollama itself, not the whole ROCm stack.
  ollamaRocmGfx1103 = pkgs.ollama-rocm.override {
    rocmGpuTargets = [ "gfx1103" ];
  };

in {
  options.services.ollamaExperiment = {
    enable = lib.mkEnableOption "Experimental Ollama instance for GPU tuning";

    port = lib.mkOption {
      type = lib.types.port;
      default = 11435;
      description = "Port for the experimental Ollama instance (must differ from main ollama's 11434).";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = ollamaRocmGfx1103;
      defaultText = "ollama-rocm rebuilt with AMDGPU_TARGETS = [\"gfx1103\"]";
      description = ''
        Which Ollama package to run. Options:
          pkgs.ollama-rocm          — stock nixpkgs ROCm build
          pkgs.ollama               — CPU/Vulkan, no ROCm
          config.services.ollamaExperiment._ollamaRocmGfx1103 (default)
                                    — ROCm rebuilt for gfx1103
      '';
    };

    rocmOverrideGfx = lib.mkOption {
      type = lib.types.str;
      default = "11.0.3";
      description = "HSA_OVERRIDE_GFX_VERSION passed to the service.";
    };

    extraEnv = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = { HSA_ENABLE_SDMA = "0"; OLLAMA_DEBUG = "1"; };
      description = "Extra environment variables to pass to the experimental Ollama service.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "steve";
      description = "User to add to render/video groups for GPU access.";
    };
  };

  config = lib.mkIf cfg.enable {
    # ROCm needs OpenCL ICD platform files installed system-wide so the
    # runtime can locate the GPU. Without this the discovery runner crashes.
    hardware.graphics.extraPackages = with pkgs; [
      rocmPackages.clr.icd
    ];

    environment.systemPackages = [ cfg.package ];

    users.users.${cfg.user}.extraGroups = [ "render" "video" ];

    systemd.services.ollama-experiment = {
      description = "Ollama (experimental GPU tuning instance)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        HOME           = "/var/lib/ollama-experiment";
        OLLAMA_MODELS  = "/var/lib/ollama-experiment/models";
        OLLAMA_HOST    = "127.0.0.1:${toString cfg.port}";
        HSA_OVERRIDE_GFX_VERSION = cfg.rocmOverrideGfx;
        # libggml-base.so.0 lives alongside libggml-hip.so; the discovery
        # subprocess needs this so the dynamic linker can find it.
        LD_LIBRARY_PATH = "${cfg.package}/lib/ollama";
      } // cfg.extraEnv;

      serviceConfig = {
        ExecStart       = "${cfg.package}/bin/ollama serve";
        Restart         = "on-failure";
        User            = cfg.user;
        StateDirectory  = "ollama-experiment";
        # Give the service process GPU device access.
        SupplementaryGroups = [ "render" "video" ];
      };
    };
  };
}
