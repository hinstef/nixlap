{
  description = "NixOS Configuration for Laptop";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    nix-pi.url = "github:hinstef/nix-pi";
    nix-pi.inputs.nixpkgs.follows = "nixpkgs";

    nixadmin.url = "github:hinstef/nixadmin/main";
    nixadmin.inputs.nixpkgs.follows = "nixpkgs";

    # Private repo containing settings.nix and hardware-configuration.nix.
    # Fork or create your own and update this URL before building.
    # See settings.nix.example for the expected contents.
    private = {
      url = "git+ssh://git@github.com/hinstef/nixlap-private";
      flake = false;
    };
  };

  outputs = { nixpkgs, private, ... }@inputs:
    let
      userSettings = import "${private}/settings.nix";
      settings = userSettings // {
        # Single source of truth for the working tree. system.autoUpgrade and
        # services.nixadmin both rebuild from this path and must not disagree —
        # if they do, whichever ran last silently reverts the other.
        flakeDir = userSettings.flakeDir or "/home/${userSettings.username}/workspace/nixlap";
      };
      laptop = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs settings; };
        modules = [
          ./hosts/laptop/default.nix
          inputs.home-manager.nixosModules.home-manager
          inputs.sops-nix.nixosModules.sops
          inputs.nix-flatpak.nixosModules.nix-flatpak
          inputs.nixadmin.nixosModules.default
        ];
      };
    in
    {
      nixosConfigurations.${settings.hostname} = laptop;

      # `nix flake check` builds this. The nightly upgrade runs it as a preflight
      # before anything touches the running system — see modules/nixos/auto-upgrade.nix.
      # It is the same derivation nixos-rebuild would build, so the check costs
      # nothing extra: the switch that follows reuses it from the store.
      checks.${laptop.pkgs.stdenv.hostPlatform.system}.toplevel =
        laptop.config.system.build.toplevel;
    };
}
