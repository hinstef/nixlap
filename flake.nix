{
  description = "NixOS Configuration for Laptop";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    plasma-manager.url = "github:nix-community/plasma-manager";
    plasma-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.inputs.home-manager.follows = "home-manager";

    nix-pi.url = "github:hinstef/nix-pi";
    nix-pi.inputs.nixpkgs.follows = "nixpkgs";

    nixadmin.url = "github:hinstef/nixadmin";
    nixadmin.inputs.nixpkgs.follows = "nixpkgs";

    # Nixpkgs master — used only to pull a newer Ollama than unstable has packaged.
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixpkgs-master.inputs = {};  # no follows — intentionally unpinned

    # Private repo containing settings.nix and hardware-configuration.nix.
    # Fork or create your own and update this URL before building.
    # See settings.nix.example for the expected contents.
    private = {
      url = "git+ssh://git@github.com/hinstef/nixlap-private";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, sops-nix, nix-flatpak, plasma-manager, nix-pi, nixadmin, nixpkgs-master, private, ... }@inputs:
    let
      settings = import "${private}/settings.nix";
    in
    {
      nixosConfigurations.${settings.hostname} = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs settings; };
        modules = [
          ./hosts/laptop/default.nix
          home-manager.nixosModules.home-manager
          sops-nix.nixosModules.sops
          nix-flatpak.nixosModules.nix-flatpak
          nixadmin.nixosModules.default
        ];
      };
    };
}
