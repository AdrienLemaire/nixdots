{ lib, ... }:
{
  # Force a clean Hyprland config reload at the end of every home-manager
  # activation.
  #
  # Why this is needed: HyDE ships a windowrules.conf written for a different
  # Hyprland rule-syntax generation than the one we run. During `nixos-rebuild
  # switch`, linkGeneration briefly places that broken default, Hyprland
  # auto-reloads and surfaces ~100 config errors, and the follow-up
  # `cp --remove-destination` of our corrected file (mutableFileGeneration) does
  # NOT reliably trigger a complete reparse — so the Error Overlay lingers until
  # a manual `hyprctl reload`, which is itself awkward from tmux (see the
  # update-environment note in tmux.nix). This makes the compositor always land
  # on the corrected, error-free config.
  #
  # The live instance signature can't be read from /proc (Hyprland marks itself
  # non-dumpable), so probe each runtime socket dir with `hyprctl version` and
  # reload the one that answers. Non-fatal; a no-op when Hyprland isn't running
  # (TTY / first boot). Uses the system hyprctl so the IPC version always matches
  # the running compositor.
  home.activation.reloadHyprland = lib.hm.dag.entryBefore [ "reloadSystemd" ] ''
    _hyprctl=/run/current-system/sw/bin/hyprctl
    _rt="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    if [ -x "$_hyprctl" ] && [ -d "$_rt/hypr" ]; then
      for _d in "$_rt"/hypr/*/; do
        _s=$(basename "$_d")
        if HYPRLAND_INSTANCE_SIGNATURE="$_s" "$_hyprctl" version >/dev/null 2>&1; then
          $VERBOSE_ECHO "Reloading Hyprland ($_s) after config deploy"
          $DRY_RUN_CMD env HYPRLAND_INSTANCE_SIGNATURE="$_s" "$_hyprctl" reload >/dev/null 2>&1 || true
        fi
      done
    fi
  '';
}
