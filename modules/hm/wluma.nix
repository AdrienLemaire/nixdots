# Adaptive brightness from the ambient light sensor (iio "als", read directly
# from sysfs; no iio-sensor-proxy needed). wluma 5 learns from manual changes:
# a brightness key press is remembered for that light level and screen
# content. The 5.x package override and the backlight udev rule live in
# modules/system/wluma.nix.
{ lib, pkgs, ... }:

let
  # HyDE's hypridle dims eDP-1 to 1% with brightnessctl after 60 s idle.
  # wluma cannot tell that from a user adjustment, so it would learn "1% at
  # this lux". wluma's own [idle] dimming replaces it (below) and is applied
  # on top of the prediction without being learned.
  hydeHypridle = lib.readFile "${pkgs.hyde}/Configs/.config/hypr/hypridle.conf";
  dimListener = ''
    listener {
        timeout = 60
        on-timeout = brightnessctl -s && brightnessctl s 1% # Save and set brightness to 1%
        on-resume = brightnessctl -r # Restore brightness on activity
    }
  '';
in
{
  hydenix.hm.hyprland.hypridle.overrideConfig =
    if lib.hasInfix dimListener hydeHypridle then
      builtins.replaceStrings [ dimListener ] [ "" ] hydeHypridle
    else
      throw "modules/hm/wluma.nix: HyDE's hypridle dim listener changed upstream; update dimListener.";

  services.wluma = {
    enable = true;
    systemd.enable = true;
    settings = {
      idle = {
        timeout = 60;
        brightness = 10;
      };

      output = {
        # gamma = false: hyprsunset owns colour temperature, and wluma's
        # learned dim/temperature would fight its schedule.
        backlight = [
          {
            name = "eDP-1";
            gamma = false;
          }
        ];
        # No external answers DDC/CI (S3 pair: no support; Dell: the
        # USB-C->HDMI adapter NACKs it). Excluded so wluma doesn't poll dead
        # buses every 500 ms. Re-enable DP-4 once it sits on a DDC-capable link.
        ddcutil =
          map
            (name: {
              inherit name;
              enabled = false;
            })
            [
              "DP-2"
              "DP-3"
              "DP-4"
            ];
      };

      # The XPS keyboard backlight stays under manual control (Fn+F5).
      keyboard = [
        {
          name = "keyboard";
          path = "/sys/class/leds/dell::kbd_backlight";
          enabled = false;
        }
      ];
    };
  };
}
