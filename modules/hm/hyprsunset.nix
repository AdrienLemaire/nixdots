{ ... }:

{
  # Scheduled warm shift for eye comfort. It also gives HyDE's waybar
  # night-light button (custom/hyprsunset -> ~/.local/lib/hyde/hyprsunset.sh)
  # the daemon it expects: that script only spawns hyprsunset when pgrep finds
  # none, then drives it over `hyprctl hyprsunset` IPC.
  #
  # Leave the waybar toggle OFF for the schedule to rule: while it is ON, its
  # periodic `--read` re-applies the saved temperature over the profile. A
  # toggle-off sends identity, which holds until the next profile boundary.
  #
  # `gamma` here is a 0.0-1.0 float, unlike the 20-100 scale of the CLI and
  # HyDE's script. It is kept at 1.0: hyprsunset's gamma scales the CTM, which
  # dims by crushing contrast with the backlight still at full output.
  services.hyprsunset = {
    enable = true;
    settings.profile = [
      {
        time = "7:00";
        identity = true;
      }
      {
        time = "19:00";
        temperature = 4500;
        gamma = 1.0;
      }
      {
        time = "22:00";
        temperature = 3500;
        gamma = 1.0;
      }
    ];
  };
}
