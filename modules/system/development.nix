{ pkgs, ... }: {
  # Necessary to use volta-installed node
  # used by copilot and marksman
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [ icu ];
  };
}