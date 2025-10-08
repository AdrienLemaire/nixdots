{ inputs, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [

    # SYSTEM UTILITIES
    plocate
    ripgrep.out
    wget

    # glances mission-center
    btop
    gcc
    fd
    lazygit
    tree-sitter
    cargo
    unzip
    lynx
    sox
    sof-firmware
    v4l-utils
    powertop
    ddcutil
    git-lfs

    # BROWSERS
    google-chrome
    firefox

    # KEYBOARD LAYOUTS
    qwerty-fr

    # KERNEL MODULES
    linuxKernel.packages.linux_zen.ipu6-drivers

    # SCREEN RECORDING
    wf-recorder
    grim
    satty
    obs-studio
    kdePackages.kdenlive

    # MEDIA TOOLS
    mplayer
    ffmpeg
    yt-dlp
    zathura
    llpp
    gimp3-with-plugins
    userPkgs.cxxopts  # trying to fix issue https://github.com/nixos/nixpkgs/issues/449068

    # TERMINALS
    ghostty

    # AI
    aider-chat
    goose-cli
    claude-code
    inputs.mcp-hub.packages.x86_64-linux.default
    n8n

    # SHELLS
    nushell
    starship

    # COMPLETION TOOLS
    zoxide
    carapace
    inshellisense

    # DEVELOPMENT TOOLS
    nodejs_24
    marksman
    pipx
    gh

    # Vim
    vimPlugins.LazyVim
    ghostscript # needed by snacks.image for pdf support in vim
    mermaid-cli # render mermaid diagrams in vim
    uv # python needed by MCPHub
    ast-grep # dependency for vim grug-far
    sqlite # for snacks.picker history
    luarocks # Lua package manager
    rustc # Required for luarocks-build-rust-mlua
    cargo # Required for building Rust-based Lua modules

    # FILE MANAGERS
    kdePackages.dolphin

    # GAMES
    (lutris.override {
      extraPkgs = pkgs: [
        # C-Dogs
        SDL2_mixer
        flac
        # bombsquad
        python312
      ];
      extraLibraries = pkgs: [
        "${python312}/lib"
        "${flac}/lib"
        "${SDL2_mixer}/lib"
      ];
    })
    bombsquad

    # MISC
    gcalcli
    pueue # for task.nu
    wgnord
    pass

  ];

  environment.variables = lib.mkForce {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # environment.sessionVariables = {
  #   XMODIFIERS = "@im=fcitx";
  #   QT_IM_MODULE = "fcitx";
  #   GTK_IM_MODULE = "fcitx";
  #   SDL_IM_MODULE = "fcitx"; # Optional, for SDL-based apps
  # };

  xdg.mime = {
    enable = true;
    defaultApplications = {
      "text/html" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "x-scheme-handler/about" = "firefox.desktop";
      "x-scheme-handler/unknown" = "firefox.desktop";
      "application/pdf" = "zathura.desktop";
    };
  };
}
