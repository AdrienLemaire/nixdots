    { ... }:
{
  # https://raw.githubusercontent.com/richen604/hydenix/5665cfabc7e18ee8267c4a23e1dcbdbaa4228a0b/hydenix/modules/system/nix.nix
  nix.settings = {
    trusted-users = ["root" "dori"];
    download-buffer-size = 104857600;
    http-connections = 50;
    max-jobs = "auto";
  };
}
