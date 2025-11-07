{ pkgs, ... }: {
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
    settings = {
      capture = "pipewire";
      encoder = "vaapi";
    };
  };

  environment.variables = {
    WAYLAND_DISPLAY = "wayland-1";
    XDG_SESSION_TYPE = "wayland";
    LIBVA_DRIVER_NAME = "iHD";
  };


  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-wlr ];
  };

  services.avahi.publish.enable = true;
  services.avahi.publish.userServices = true;

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver  # Modern Intel GPUs (12th/13th Gen+)
      vpl-gpu-rt  # VPL runtime for newer GPUs    ];
    ];
  };

  # Add for VA-API device access
  users.users.dori.extraGroups = [ "video" "render" ];
}
