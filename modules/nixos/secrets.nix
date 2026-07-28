{ pkgs, config, ... }:

{
  # sops-nix configuration

  # To use sops-nix:
  # 1. Generate an age key: age-keygen -o /var/lib/sops-nix/key.txt
  # 2. Create a secrets.yaml file with sops: sops secrets/secrets.yaml
  # 3. Uncomment the lines below and add your secrets.

  # sops.defaultSopsFile = ../../secrets/secrets.yaml;
  # sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  # sops.secrets.example_secret = {};

  environment.systemPackages = [ pkgs.sops ];
}
