{ pkgs, inputs, settings, ... }:

{
  imports = [ ./cosmic-settings.nix ];

  home.username = settings.username;
  home.homeDirectory = "/home/${settings.username}";

  home.packages = with pkgs; [
    (writeShellScriptBin "nixadmin-apps" ''
      echo "=== Nix packages ==="
      grep -E '^\s+[a-z][a-zA-Z0-9_.-]+\s*$' /home/steve/workspace/nixlap/modules/home-manager/default.nix \
        | sed 's/^\s*//'
      echo ""
      echo "=== Flatpak apps ==="
      flatpak list --app --columns=name,application
    '')
    thunderbird
    firefox
    google-chrome
    vscode
    spotify
    podman-desktop
    usbutils
    # Steam is installed system-wide for udev rules, but we can add utils here if needed.
    inputs.ghostty.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.nix-pi.packages.${pkgs.stdenv.hostPlatform.system}.default
    gemini-cli
    signal-desktop
    nextcloud-client
    zellij # terminal multiplexer
    claude-code
    # Kubernetes
    kubectl
    k9s
    kubernetes-helm
    # Containers
    podman-compose
    # Python
    python3
    tree
    uv
    ruff
    # Data
    jq
    stirling-pdf-desktop
    rendercv
  ];

  home.file.".pi/agent/models.json".text = builtins.toJSON {
    providers = {
      ollama = {
        baseUrl = "http://localhost:11434/v1";
        api     = "openai-completions";
        apiKey  = "ollama";
        models  = [{ id = "llama3.1:8b"; } { id = "qwen2.5-coder:14b"; } { id = "qwen-tool"; }];
      };
    };
  };

  programs.zsh = {
    enable = true;
    shellAliases = {
      nixadmin = "cd /home/steve/workspace/nixlap && pi --model ollama/llama3.1:8b";
    };
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [ "git" ];
    };
    plugins = [
      {
        name = "zsh-autosuggestions";
        src = pkgs.zsh-autosuggestions;
        file = "share/zsh-autosuggestions/zsh-autosuggestions.zsh";
      }
      {
        name = "zsh-syntax-highlighting";
        src = pkgs.zsh-syntax-highlighting;
        file = "share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";
      }
    ];
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name  = settings.fullName;
        email = settings.email;
      };
      init.defaultBranch = "main";
    };
  };

  programs.home-manager.enable = true;

  # WARNING: Do NOT change this. It is NOT your NixOS version — it controls backward compatibility.
  # See: https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "25.11";
}
