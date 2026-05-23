{ pkgs, inputs, settings, ... }:

{
  imports = [ ./kde-settings.nix ];

  home.username = settings.username;
  home.homeDirectory = "/home/${settings.username}";

  home.packages = with pkgs; [
    thunderbird
    firefox
    google-chrome
    vscode
    spotify
    podman-desktop
    kdePackages.gwenview
    usbutils
    # Steam is installed system-wide for udev rules, but we can add utils here if needed.
    inputs.ghostty.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.nix-pi.packages.${pkgs.stdenv.hostPlatform.system}.default
    gemini-cli
    signal-desktop
    trayscale
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
  ];

  home.file.".pi/agent/models.json".text = builtins.toJSON {
    providers = {
      ollama = {
        baseUrl = "http://localhost:11434/v1";
        api     = "openai-responses";
        apiKey  = "ollama";
        models  = [{ id = "llama3.1:8b"; } { id = "qwen2.5-coder:7b"; } { id = "gemma4:e2b"; }];
      };
    };
  };

  programs.zsh = {
    enable = true;
    shellAliases = {
      nixadmin = "cd /home/steve/workspace/nixlap && pi";
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
