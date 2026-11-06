# Aquamarine 0.15.0 (Hyprland's DRM backend) never disables the KMS pipeline of
# an output whose monitor gets unplugged: the connector reads
# "disconnected enabled" in /sys/class/drm. On Intel Type-C, that orphaned CRTC
# keeps the port's PHY locked in its old mode, so the USB-C -> HDMI monitor
# stays black on replug (AUX reads fail with -6) until the session exits or a
# VT switch makes fbcon reclaim the pipes.
#
# Fixed upstream in 0.15.1 ("drm: release output on disconnect manually",
# hyprwm/aquamarine#410). Pin it until the locked nixpkgs ships 0.15.1, then
# delete this file. System overlay for the same reason as swww-compat.nix.
{ lib, ... }:

{
  nixpkgs.overlays = [
    (final: prev: {
      aquamarine =
        assert lib.assertMsg (lib.versionOlder prev.aquamarine.version "0.15.1")
          "nixpkgs ships aquamarine >= 0.15.1: remove modules/system/aquamarine-hotplug.nix";
        prev.aquamarine.overrideAttrs (_: rec {
          version = "0.15.1";
          src = final.fetchFromGitHub {
            owner = "hyprwm";
            repo = "aquamarine";
            tag = "v${version}";
            hash = "sha256-jiUl3+k9K+BASO4hvKFhlCMUpHPPoy2q5uZMl3pzOF0=";
          };
        });
    })
  ];
}
