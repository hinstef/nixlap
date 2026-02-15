{
  description = "NixOS Configuration for Laptop";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Home Manager
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Sops-Nix for secrets
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # Nix-Flatpak for declarative flatpaks
    nix-flatpak.url = "github:gmodena/nix-flatpak";

    # Ghostty Terminal
    ghostty.url = "github:ghostty-org/ghostty";
  };

  outputs = { self, nixpkgs, home-manager, sops-nix, nix-flatpak, ghostty, ... }@inputs: {
    nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/laptop/default.nix
        home-manager.nixosModules.home-manager
        sops-nix.nixosModules.sops
        nix-flatpak.nixosModules.nix-flatpak
        {
          environment.systemPackages = [ ghostty.packages.x86_64-linux.default ];
        }
      ];
    };
  };
}
