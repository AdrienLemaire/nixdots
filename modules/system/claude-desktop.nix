{ inputs, pkgs, ... }:

# Installing (not `nix run`) puts com.anthropic.Claude.desktop on XDG_DATA_DIRS,
# which registers the claude:// handler the browser login redirects back to.
let
  upstream = inputs.claude-desktop.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop;

  # Chromium picks basic_text on unknown desktops (Hyprland), which the app
  # refuses for storing the sign-in; point it at the Secret Service instead.
  claude-desktop = upstream.overrideAttrs (old: {
    preFixup = old.preFixup + ''
      gappsWrapperArgs+=(--add-flags --password-store=gnome-libsecret)
    '';
  });
in
{
  imports = [ inputs.claude-desktop.nixosModules.default ];

  programs.claude-desktop = {
    enable = true;
    package = claude-desktop;
  };

  # Secret Service backend, unlocked by the login password through PAM
  services.gnome.gnome-keyring.enable = true;

  xdg.mime.defaultApplications."x-scheme-handler/claude" = "com.anthropic.Claude.desktop";
}
