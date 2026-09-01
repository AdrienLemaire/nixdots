{ ... }: {
  # External monitors expose no /sys/class/backlight device -- only the internal
  # eDP-1 panel does (intel_backlight). The only way to set their brightness is
  # DDC/CI over the display's I2C side-channel, which needs the i2c-dev char
  # devices; without this, `ddcutil detect` fails outright with
  # "No /dev/i2c devices exist".
  #
  # This also creates the "i2c" group, but membership is not required here:
  # the module's udev rules tag the nodes uaccess, so the locally seated user
  # gets access from logind. Consumed by modules/hm/scripts/brightness-all.sh.
  hardware.i2c.enable = true;
}
