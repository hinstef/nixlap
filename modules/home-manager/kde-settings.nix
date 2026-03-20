{ inputs, ... }:

{
  imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

  home.file.".local/share/kxmlgui5/dolphin/dolphinui.rc".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE gui SYSTEM "kpartgui.dtd">
    <gui name="dolphin" version="48">
        <ToolBar noMerge="1" name="mainToolBar">
            <text context="@title:menu">Main Toolbar</text>
            <Action name="go_back" />
            <Action name="go_forward" />
            <Action name="view_settings" />
            <Action name="url_navigators" />
            <Action name="split_view" />
            <Action name="split_stash" />
            <Action name="toggle_search" />
            <Action name="new_menu" />
            <Action name="movetotrash" />
            <Action name="hamburger_menu" />
        </ToolBar>
    </gui>
  '';

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
