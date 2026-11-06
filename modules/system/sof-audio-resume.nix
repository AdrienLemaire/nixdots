# The SOF DSP loses an open PCM across system sleep. If a stream is open on
# the internal card when the laptop suspends (Firefox, the "Speakers (Loud)"
# filter), the kernel tries to restore it on resume and the firmware rejects
# it:
#   sof_pcm_prepare: pcm2 (Speaker), dir 0: failed to set hw_params after resume
# The PCM then sits in SETUP forever and PipeWire's recovery loops on
# "snd_pcm_prepare error: Invalid argument": no sound until the device is
# closed and reopened (seen 2026-10-26 after a 00:04 resume).
#
# Suspending the PipeWire nodes closes the PCMs; any node with a live stream
# reopens straight away with fresh hw_params. Unlike restarting pipewire this
# keeps every client connected, which matters because a long-lived Firefox
# never reconnects its camera after a pipewire restart.
#
# suspend.target & co. are only *reached* after resume (systemd-suspend.service
# has finished), so After= + WantedBy= on them runs this on wake-up.
{ config, pkgs, ... }:

let
  sleepTargets = [
    "suspend.target"
    "hibernate.target"
    "hybrid-sleep.target"
    "suspend-then-hibernate.target"
  ];
in
{
  systemd.services.sof-audio-resume = {
    description = "Reopen internal sound card PCMs after resume";
    wantedBy = sleepTargets;
    after = sleepTargets;
    serviceConfig.Type = "oneshot";
    path = [ config.services.pipewire.package pkgs.jq pkgs.util-linux pkgs.coreutils ];
    script = ''
      export XDG_RUNTIME_DIR=/run/user/$(id -u dori)
      # Let the thawed (or systemd-restarted) pipewire settle first.
      sleep 2
      runuser -u dori -- pw-dump \
        | jq -r '.[] | select(.type == "PipeWire:Interface:Node")
                     | select(.info.props["node.name"] // "" | contains("sof_sdw"))
                     | .id' \
        | while read -r id; do
            runuser -u dori -- pw-cli send-command "$id" Suspend '{}' >/dev/null
          done
    '';
  };
}
