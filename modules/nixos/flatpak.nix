{ pkgs, ... }:

{
  services.flatpak.enable = true;

  # Declarative flatpak management via nix-flatpak
  services.flatpak.packages = [
    "com.github.tchx84.Flatseal"
    "org.gimp.GIMP"
    "com.bitwarden.desktop"
  ];

  services.flatpak.update.onActivation = true;

  # Add flathub remote if not present (nix-flatpak handles this mostly but good to be explicit if needed)
  services.flatpak.remotes = [
    { name = "flathub"; location = "https://dl.flathub.org/repo/flathub.flatpakrepo"; }
  ];
}
