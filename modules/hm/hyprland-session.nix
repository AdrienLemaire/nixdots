# xdg-desktop-portal 1.22 added `Requisite=graphical-session.target` to its unit;
# 1.20 only needed dbus.service. SDDM launches Hyprland through a plain session
# script -- no uwsm -- and hydenix writes hyprland.conf itself rather than going
# through home-manager's hyprland module, so nothing on this machine has ever
# activated graphical-session.target. Under 1.22 that makes the portal refuse to
# start, and with no org.freedesktop.portal.Desktop there is no
# org.freedesktop.appearance, so GTK apps, Firefox and ghostty render light no
# matter what gsettings HyDE writes.
#
# graphical-session.target is RefuseManualStart, so it can only be pulled in as a
# dependency. This is the same target home-manager's hyprland module would create
# when its `systemd.enable` applied; the compositor starts and stops it from the
# exec-once/exec-shutdown pair in ./default.nix.
#
# The name matches the target home-manager's hyprland module generates, so if
# `wayland.windowManager.hyprland.enable` is ever turned on this file becomes a
# duplicate definition and should go.
#
# Activating it also unblocks everything else that was WantedBy the target and
# had silently never run: HyDE's own setTheme/setThemeDconf appliers, safeeyes,
# the polkit agent and the gvfs volume monitors.
{ ... }:

{
  systemd.user.targets.hyprland-session = {
    Unit = {
      Description = "hyprland compositor session";
      Documentation = [ "man:systemd.special(7)" ];
      # BindsTo implies Requires, which is what starts graphical-session.target,
      # and it also tears this target down if the session target goes away.
      BindsTo = [ "graphical-session.target" ];
      Wants = [ "graphical-session-pre.target" ];
      After = [ "graphical-session-pre.target" ];
    };
  };
}
