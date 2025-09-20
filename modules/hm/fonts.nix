{ pkgs, ... }: {
  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      monospace = [ "DejaVu Sans Mono" "IPAGothic" ];
      sansSerif = [ "DejaVu Sans" "IPAPGothic" ];
      serif = [ "DejaVu Serif" "IPAPMincho" ];
    };
  };

  home.packages = with pkgs; [
    # https://nixos.wiki/wiki/Fonts
    #nerd-fonts.fira-code
    #nerd-fonts.droid-sans-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    liberation_ttf
    mplus-outline-fonts.githubRelease
    dina-font
    # proggyfonts
    carlito
    dejavu_fonts
    ipafont
    kochi-substitute
    source-code-pro
    ttf_bitstream_vera
  ];
}
