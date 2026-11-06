# Locks finished call recordings with chattr +i, so no command can delete or
# overwrite them, however it's phrased. Only *.wav: transcripts can be regenerated.
# Unlock with `sudo chattr -i <file>`, for example for the planned cleanup.
{ pkgs, ... }:

let
  recordingsDir = "/home/dori/call-recordings";
  idleMinutes = "10";

  lockFinished = pkgs.writeShellApplication {
    name = "lock-finished-recordings";
    runtimeInputs = with pkgs; [ e2fsprogs findutils psmisc ];
    text = ''
      dir="''${1:-${recordingsDir}}"
      [ -d "$dir" ] || exit 0
      find "$dir" -xdev -type f -iname '*.wav' -mmin +${idleMinutes} -print0 |
        while IFS= read -r -d "" file; do
          attrs="$(lsattr -- "$file")"
          case "''${attrs%% *}" in *i*) continue ;; esac
          # A recorder still holding the file patches its header on close.
          if fuser -s -- "$file" 2>/dev/null; then continue; fi
          chattr +i -- "$file"
          echo "locked $file"
        done
    '';
  };
in
{
  systemd.services.protect-recordings = {
    description = "Lock finished call recordings";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.lib.getExe lockFinished}";
      # Root in a user-writable folder: a swapped-in symlink must not reach other files.
      ProtectSystem = "strict";
      ReadWritePaths = [ recordingsDir ];
      NoNewPrivileges = true;
      PrivateNetwork = true;
      PrivateTmp = true;
      CapabilityBoundingSet = [ "CAP_LINUX_IMMUTABLE" "CAP_FOWNER" "CAP_DAC_READ_SEARCH" "CAP_SYS_PTRACE" ];
    };
  };

  systemd.timers.protect-recordings = {
    description = "Lock finished call recordings every 5 minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "5min";
    };
  };
}
