{
  description = "NixOS Configuration for Laptop";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    ghostty.url = "github:ghostty-org/ghostty";
  };

  outputs = { self, nixpkgs, home-manager, sops-nix, nix-flatpak, ghostty, ... }@inputs:
    let
      settings = import ./settings.nix;
    in
    {
      nixosConfigurations.${settings.hostname} = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs settings; };
        modules = [
          ./hosts/laptop/default.nix
          home-manager.nixosModules.home-manager
          sops-nix.nixosModules.sops
          nix-flatpak.nixosModules.nix-flatpak
          {
            # Patch Sushi file previewer to use 90% screen height / 75% screen width
            nixpkgs.overlays = [
              (final: prev: {
                sushi = prev.sushi.overrideAttrs (old: {
                  postPatch = (old.postPatch or "") + ''
                    substituteInPlace src/ui/mainWindow.js \
                      --replace-fail \
                        'return [Math.floor(scaleW * WINDOW_MAX_W),' \
                        'let scaleFactor = underWayland ? this.get_scale_factor() : 1;
            return [Math.floor(geometry.width * 0.75 / scaleFactor),' \
                      --replace-fail \
                        'Math.floor(scaleH * WINDOW_MAX_H)];' \
                        'Math.floor(geometry.height * 0.90 / scaleFactor)];'
                  '';
                });
              })
            ];
          }
        ];
      };
    };
}
