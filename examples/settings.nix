{ ... }: {
  bspwmBuild = {
    username = "youruser";
    uid = 1000;
    homeDirectory = "/home/youruser";
    hostName = "my-pc";
    stateVersion = "26.05"; # Keep the initial version of an existing installation.
    timeZone = "Asia/Yekaterinburg";
    ssh = { enable = false; port = 5555; authorizedKeys = []; };
    # development.enable = false;
    # virtualisation.enable = false;
    # vpn.enable = false;
    # ui = { battery = "BAT0"; adapter = "AC"; backlight = "intel_backlight"; };
  };
}
