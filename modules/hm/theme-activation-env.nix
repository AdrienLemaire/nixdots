{ lib, ... }:
{
  # hydenix's theme module re-applies the theme from a home-manager *activation
  # snippet* (`Activating setTheme`), so a full `theme.switch.sh` runs on every
  # `nixos-rebuild switch` -- separately from, and a few seconds after, the
  # setTheme.service unit of the same name.
  #
  # That snippet runs inside nixos-activation.service, whose environment has no
  # XDG_SESSION_DESKTOP. HyDE's waybar.py names its own unit
  # `hyde-''${XDG_SESSION_DESKTOP:-unknown}-bar.service` and decides whether a bar
  # is already up by asking systemd about that exact name. Without the variable
  # it looks for hyde-unknown-bar.service, does not find the compositor's
  # hyde-Hyprland-bar.service, and starts a *second* waybar over the running one
  # -- two bars after every rebuild, until one is stopped by hand.
  #
  # All activation snippets run in one bash process, so exporting the variable
  # from an earlier entry reaches hydenix's. Only exported when a compositor is
  # actually up: during boot-time activation there is no bar to reuse, and
  # naming the unit after a session that does not exist would leave a failed
  # hyde-Hyprland-bar.service sitting in the way of the real one.
  home.activation.sessionDesktopForTheme = lib.hm.dag.entryBefore [ "setTheme" ] ''
    _rt="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    if [ -n "$(ls -A "$_rt/hypr" 2>/dev/null)" ]; then
      export XDG_SESSION_DESKTOP=Hyprland
    fi
  '';
}
