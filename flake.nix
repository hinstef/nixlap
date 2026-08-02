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
        # Where this checkout lives. services.nixadmin rebuilds from it, and it
        # keeps that path out of the host config. Overridable from settings.nix.
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

      # `nix flake check` builds this, so it is a real build and not just an eval.
      # Same derivation nixos-rebuild produces, so a check followed by a switch
      # costs nothing extra — the switch reuses it from the store.
      checks.${laptop.pkgs.stdenv.hostPlatform.system}.toplevel =
        laptop.config.system.build.toplevel;
    };
}
