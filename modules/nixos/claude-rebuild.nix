{ settings, ... }:

{
  # Lets Claude Code run `sudo nixos-rebuild ...` without a password prompt.
  # Previously provided by modules/nixos/nixadmin.nix, which stopped being
  # imported once the nixadmin flake input took over (that module does not
  # carry the sudo rules).
  #
  # Note: this is effectively passwordless root, since nixos-rebuild activates
  # whatever the flake evaluates to.
  security.sudo.extraRules = [
    {
      users = [ settings.username ];
      commands = [
        {
          command = "/run/current-system/sw/bin/nixos-rebuild *";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
