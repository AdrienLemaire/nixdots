# The healthstats plugin is the only place Safe Eyes writes break counts down,
# and `cadence/safeeyes.py` reads them out of ~/.config/safeeyes/session.json.
# nixpkgs declares croniter -- the plugin's very first import -- as an
# *optional* dependency (`optional-dependencies.healthstats`), so the closure
# ships without it: every start logs
#   ImportError: No module named 'croniter'   (plugins/healthstats/plugin.py:21)
# the plugin never loads, session.json never grows a `healthstats` key, and
# snapshot() has answered None every day since it was written.
#
# services.safeeyes has no `package` option (nixos/modules/services/misc/
# safeeyes.nix hardcodes pkgs.safeeyes for both the systemPackages entry and
# the user unit's ExecStart), so the override has to happen on the package
# itself. Same reasoning as swww-compat.nix for why this is a *system* overlay:
# home-manager runs with useGlobalPkgs and ignores `nixpkgs.*` set in a
# home-manager module.
#
# The optional set is taken rather than naming croniter again: upstream already
# says there what the plugin needs, and if it renames or drops the key this
# fails at evaluation instead of quietly going back to the broken closure.
{ ... }:

{
  nixpkgs.overlays = [
    (final: prev: {
      safeeyes = prev.safeeyes.overridePythonAttrs (old: {
        dependencies = old.dependencies ++ old.optional-dependencies.healthstats;
      });
    })
  ];
}
