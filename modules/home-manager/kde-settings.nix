{ inputs, ... }:

{
  imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

  programs.plasma = {
    enable = true;

    kwin.nightLight = {
      enable = true;
      mode = "times";
      temperature = {
        day = 6500;
        night = 4000;
      };
      time = {
        morning = "06:00";
        evening = "22:00";
      };
    };

    configFile."dolphinrc"."General".ViewMode = 1;

    configFile."kwinrc"."ElectricBorders" = {
      Bottom = "None";
      BottomLeft = "None";
      BottomRight = "None";
      Left = "None";
      Right = "None";
      Top = "None";
      TopLeft = "None";
      TopRight = "None";
    };

    panels = [
      {
        location = "bottom";
        screen = "all";
        height = 53;
        floating = true;
        hiding = "none";
        widgets = [
          "org.kde.plasma.kickoff"
          "org.kde.plasma.icontasks"
          "org.kde.plasma.marginsseparator"
          "org.kde.plasma.systemtray"
          "org.kde.plasma.digitalclock"
          "org.kde.plasma.showdesktop"
        ];
      }
    ];
  };
}
