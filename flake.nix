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
      settings = import "${private}/settings.nix";
    in
    {
      nixosConfigurations.${settings.hostname} = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs settings; };
        modules = [
          ./hosts/laptop/default.nix
          inputs.home-manager.nixosModules.home-manager
          inputs.sops-nix.nixosModules.sops
          inputs.nix-flatpak.nixosModules.nix-flatpak
          inputs.nixadmin.nixosModules.default
        ];
      };
    };
}
