{ config, lib, pkgs, ... }:
# The claudeA (~/.claude-adrien) and claudeF (~/.claude-founders) accounts see
# the same rules: one CLAUDE.md, one memory folder per project, and the same
# shared settings keys. adrien is the primary; founders links into it.
let
  home = config.home.homeDirectory;
  primary = "${home}/.claude-adrien";
  secondary = "${home}/.claude-founders";

  mkScript = name: deps: pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = deps;
    text = builtins.readFile ./scripts/${name}.sh;
  };

  shareMemory = mkScript "claude-share-memory" [ pkgs.coreutils pkgs.gnused pkgs.gnugrep pkgs.diffutils ];
  shareSettings = mkScript "claude-share-settings" [ pkgs.coreutils pkgs.jq pkgs.diffutils pkgs.gnused ];
  accountsCheck = mkScript "claude-accounts-check" [ pkgs.coreutils ];
in
{
  home.packages = [ accountsCheck ];

  home.file.".claude-founders/CLAUDE.md" = {
    source = config.lib.file.mkOutOfStoreSymlink "${primary}/CLAUDE.md";
    force = true;
  };

  # Claude Code rewrites settings.json itself, so it cannot be a store link:
  # the base's keys are applied in place and every other key is left alone.
  # The base lives in the private config dir, not this public repo or the
  # world-readable store: its autoMode/permissions describe work org internals.
  home.activation.claudeShareSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe shareSettings} ${primary}/settings-shared.json \
      ${primary}/settings.json ${secondary}/settings.json || true
  '';

  # Activation rather than home.file so projects created since the last
  # rebuild are linked too.
  home.activation.claudeShareMemory = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe shareMemory} ${primary} ${secondary} || true
  '';
}
