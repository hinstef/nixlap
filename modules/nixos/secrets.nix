{ pkgs, settings, ... }:

{
  # sops-nix. The age key lives outside the store at /var/lib/sops-nix/key.txt
  # (root-owned, 0600) and is deliberately not managed by nix.
  # Provision: age-keygen -o /var/lib/sops-nix/key.txt
  # Edit secrets: sops secrets/users.yaml
  sops.defaultSopsFile = ../../secrets/users.yaml;
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  # neededForUsers decrypts into /run/secrets-for-users *before* user activation,
  # which is what makes users.users.*.hashedPasswordFile work at all. Secrets
  # declared this way are root-only by design, so owner/mode must not be set.
  # The key in secrets/users.yaml must be named "<username>-password".
  sops.secrets."${settings.username}-password" = {
    neededForUsers = true;
  };

  environment.systemPackages = [ pkgs.sops ];
}
