{ ... }:

{
  # Declarative flatpak management via nix-flatpak. The flathub remote is the
  # module's default, so it is not restated here. Runtimes (org.freedesktop.*)
  # are pulled in as dependencies of these apps, so they are not listed either —
  # pinning one by hand only strands an old runtime once the apps move on.
  services.flatpak = {
    enable = true;

    packages = [
      "com.github.tchx84.Flatseal"
      "org.gimp.GIMP"
      "com.bitwarden.desktop"
    ];

    update.onActivation = true;
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };
  };
}
