{ config, lib, pkgs, ... }:

let
  cfg = config.services.nixadmin;

  # Vulkan backend — works on any GPU with a Vulkan driver (Mesa RADV for Radeon 780M).
  # Simpler than ROCm: no gfx target overrides, no ICD loader, no HSA env vars.
  # Performance is lower than ROCm but the setup is far more reliable on iGPUs.
  ollamaPackage = pkgs.ollama-vulkan;

  # Minimal OCI image containing the Ollama binary + its bundled ROCm libs.
  # cacert is required so Ollama can pull models over HTTPS.
  # The image is built entirely from the Nix store — no Dockerfile, no registry.
  ollamaImage = pkgs.dockerTools.buildLayeredImage {
    name = "nixadmin-ollama";
    tag  = "latest";
    contents = with pkgs; [
      ollamaPackage
      dockerTools.fakeNss   # minimal /etc/passwd, /etc/group, /etc/nsswitch.conf
      cacert                # TLS CA bundle for HTTPS model pulls
    ];
    config = {
      Cmd = [ "${ollamaPackage}/bin/ollama" "serve" ];
      Env = [
        "OLLAMA_MODELS=/models"
        "OLLAMA_HOST=127.0.0.1:11434"
        "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        "HOME=/root"
      ];
    };
  };

  # Only reload the OCI image when the nix store path changes (i.e. after nixos-rebuild switch).
  # Without caching, podman load runs on every container start — slow and wasteful.
  loadScript = pkgs.writeShellScript "nixadmin-ollama-load" ''
    STAMP="$HOME/.local/state/nixadmin-ollama-image"
    IMAGE="${ollamaImage}"
    if [ "$(cat "$STAMP" 2>/dev/null)" != "$IMAGE" ]; then
      ${pkgs.podman}/bin/podman load -i "$IMAGE" && \
        mkdir -p "$(dirname "$STAMP")" && \
        echo "$IMAGE" > "$STAMP"
    fi
  '';

  # Shell script for ExecStart — lets us use \ line continuations cleanly.
  startScript = pkgs.writeShellScript "nixadmin-ollama-start" ''
    exec ${pkgs.podman}/bin/podman run --rm \
      --name=nixadmin-ollama \
      --volume=nixadmin-models:/models \
      --env=OLLAMA_MODELS=/models \
      --env=OLLAMA_HOST=127.0.0.1:11434 \
      --env=SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt \
      --env=HOME=/root \
      --env=OLLAMA_VULKAN=1 \
      --env=VK_ICD_FILENAMES=/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json \
      --volume=/run/opengl-driver:/run/opengl-driver:ro \
      --volume=/nix/store:/nix/store:ro \
      --tmpfs=/tmp \
      --device=/dev/dri \
      --network=host \
      --security-opt=no-new-privileges \
      nixadmin-ollama:latest
  '';

in {
  options.services.nixadmin = {
    enable = lib.mkEnableOption "nixadmin AI sysadmin";

    user = lib.mkOption {
      type        = lib.types.str;
      example     = "steve";
      description = "User who runs the nixadmin container (rootless Podman).";
    };

    model = lib.mkOption {
      type        = lib.types.str;
      default     = "qwen2.5-coder:7b";
      description = "Ollama model the agent uses. Pull it with: podman exec nixadmin-ollama ollama pull <model>";
    };
  };

  config = lib.mkIf cfg.enable {
    # Mesa RADV (Vulkan driver for AMD) is already included in hardware.graphics
    # via KDE/Mesa defaults — no extra host packages needed for Vulkan.

    users.users.${cfg.user} = {
      extraGroups = [ "render" "video" ];
      # Required for rootless Podman (user namespace uid/gid mapping).
      subUidRanges = [{ startUid = 100000; count = 65536; }];
      subGidRanges = [{ startGid = 100000; count = 65536; }];
    };

    # Dedicated system user for privileged sysadmin operations.
    # Scoped sudo rules mean this user can only do nixos-rebuild and podman exec —
    # nothing else. cfg.user (steve) can become nixadmin without a password,
    # so Claude Code can run rebuilds without a fingerprint/password prompt.
    users.users.nixadmin = {
      isSystemUser = true;
      group        = "nixadmin";
      description  = "Scoped user for AI sysadmin operations";
    };
    users.groups.nixadmin = {};

    security.sudo.extraRules = [
      # cfg.user gets passwordless access to the two operations Claude Code needs.
      # nixos-rebuild switch requires root; podman exec targets only this container.
      # nixadmin user is reserved for the Phase 3 privileged helper daemon.
      {
        users    = [ cfg.user ];
        commands = [
          { command = "/run/current-system/sw/bin/nixos-rebuild *"; options = [ "NOPASSWD" ]; }
          { command = "${pkgs.podman}/bin/podman exec nixadmin-ollama *"; options = [ "NOPASSWD" ]; }
        ];
      }
    ];

    # Enable linger so the user service starts at boot without an active login session.
    systemd.tmpfiles.rules = [
      "f /var/lib/systemd/linger/${cfg.user} 0644 root root -"
    ];

    virtualisation.podman.enable = true;

    # Rootless Podman — runs as cfg.user, no sudo needed for podman exec.
    systemd.user.services.nixadmin-ollama = {
      description = "nixadmin Ollama inference (rootless Podman)";
      # Start after the graphical session is ready — keeps it out of the boot critical path.
      after    = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStartPre = [
          # Load image only when the nix store path has changed (post nixos-rebuild switch).
          "${loadScript}"
          # Remove any stale container from a previous unclean exit.
          # Leading '-' tells systemd to ignore a non-zero exit code here.
          "-${pkgs.podman}/bin/podman rm -f nixadmin-ollama"
        ];
        ExecStart  = "${startScript}";
        ExecStop   = "${pkgs.podman}/bin/podman stop nixadmin-ollama";
        Restart    = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
