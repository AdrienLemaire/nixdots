{ pkgs, ... }: {
  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [ fcitx5-mozc fcitx5-gtk catppuccin-fcitx5 ];
    };
  };
}