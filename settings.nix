{
  # User account
  username = "steve";
  fullName = "Steffen";
  email = "steven@posteo.de";
  hashedPassword = "$y$j9T$CrhuM.WqguUcJRHwoQ8hw/$fuffjxq4ayK3G82VvK4qem5N821pR123gpRE9tXxcy.";

  # System
  hostname = "laptop";
  timezone = "America/New_York";
  locale = "en_US.UTF-8";

  # Hibernation (requires a swapfile — see modules/nixos/features.nix for setup instructions)
  hibernate = true;
  resumeDevice = "/dev/mapper/cryptroot";
  resumeOffset = "3417344";
}
