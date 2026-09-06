# hydenix's Bibata-Modern-Ice package (hydenix/sources/Bibata-Modern-Ice.nix)
# fetches its tarball from a *floating* branch URL:
#
#   https://github.com/HyDE-Project/HyDE/raw/refs/heads/master/Source/arcs/Cursor_BibataIce.tar.gz
#
# Upstream HyDE has since removed that path from master, so the URL now 404s
# and the fixed-output derivation cannot be rebuilt. It only stayed invisible
# because the old output was still in the nix store; any nixpkgs bump changes
# the stdenv, forces a rebuild, and the build dies on the dead link.
#
# hydenix already pins the HyDE tree it wants as a flake input, and that tree
# still carries the file -- byte-identical, its sha256 matches the hash
# hydenix declares. So point src at the pinned input instead of the network.
# This is not a version change: same bytes, just fetched from the pin rather
# than from a branch tip that moved.
#
# mkAfter so this overlay is guaranteed to compose after hydenix's own (which
# is where Bibata-Modern-Ice is defined in the first place).
{ inputs, lib, ... }:

{
  nixpkgs.overlays = lib.mkAfter [
    (_final: prev: {
      Bibata-Modern-Ice = prev.Bibata-Modern-Ice.overrideAttrs (_: {
        src = "${inputs.hydenix.inputs.hyde}/Source/arcs/Cursor_BibataIce.tar.gz";
      });
    })
  ];
}
