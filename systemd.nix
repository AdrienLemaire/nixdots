{ pkgs,  ... }: {
  systemd.services.bt-resume = {
    description = "Reconnect Bluetooth keyboard after resume";
    after = [ "systemd-suspend.service" ];
    wantedBy = [ "sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bluez}/bin/bluetoothctl connect DA:93:5C:84:63:ED";
      ExecStartPost = "/bin/sleep 2"; # optional short delay for reliability
    };
  };
}
