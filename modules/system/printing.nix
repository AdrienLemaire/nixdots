{ inputs, pkgs, ... }: {
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  services.printing = {
    enable = true;
    drivers = with pkgs; [
      cups-filters
      cups-browsed
    ];
  };

  hardware.printers = {
    ensurePrinters = [
      {
        name = "HP_Smart_Tank_5100_series_F1C69D";
        # DHCP address; give the printer a static lease in the Freebox if it changes
        deviceUri = "ipp://192.168.1.198/ipp/print";
        model = "everywhere";
        description = "HP Smart Tank 5100 series";
      }
    ];
    ensureDefaultPrinter = "HP_Smart_Tank_5100_series_F1C69D";
  };
}
