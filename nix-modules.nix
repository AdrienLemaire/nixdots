{ pkgs, ... }: {
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      # https://nixos.wiki/wiki/Fonts
      #nerd-fonts.fira-code
      #nerd-fonts.droid-sans-mono
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
      liberation_ttf
      mplus-outline-fonts.githubRelease
      dina-font
      proggyfonts
      carlito
      dejavu_fonts
      ipafont
      kochi-substitute
      source-code-pro
      ttf_bitstream_vera
    ];
    fontconfig.defaultFonts = {
      monospace = [ "DejaVu Sans Mono" "IPAGothic" ];
      sansSerif = [ "DejaVu Sans" "IPAPGothic" ];
      serif = [ "DejaVu Serif" "IPAPMincho" ];
    };
  };

  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [ fcitx5-mozc fcitx5-gtk catppuccin-fcitx5 ];
    };
  };

  # Necessary to use volta-installed node
  # used by copilot and marksman
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [ icu ];
  };

  # GnuPG
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryPackage = pkgs.pinentry-rofi;
    # These settings help with passphrase caching
    # in /etc/gnupg/gpg-agent.conf
    settings = {
      default-cache-ttl = 86400; # 1 day
      default-cache-ttl-ssh = 86400; # 1 day
      max-cache-ttl = 86400; # 1 day
      max-cache-ttl-ssh = 86400; # 1 day
    };
  };

  users.users.dori.homeMode = "701";
}
