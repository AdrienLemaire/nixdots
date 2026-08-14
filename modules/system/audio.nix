{ inputs, pkgs, ... }: {
  services.pipewire = {
    enable = true;
    audio.enable = true;  # RTKit for real-time priority (reduces crackles on XPS)
    package = inputs.older-pipewire.legacyPackages.${pkgs.system}.pipewire;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber = {
      enable = true;
      package = inputs.older-pipewire.legacyPackages.${pkgs.system}.wireplumber;

      # Every key inside `matches` and `update-props` — and every section name —
      # must be written as ONE quoted, flat, dotted string. Nix expands an
      # unquoted `node.name = "x"` into a nested attrset, which serialises to
      # {"node":{"name":"x"}}; WirePlumber only understands {"node.name":"x"}
      # and silently ignores the nested form. Everything in this file was inert
      # for that reason until 2026-08-14. Verify a change actually landed with:
      #   pw-dump | jq '.[]|select(.info.props["node.name"]=="<name>").info.props'
      extraConfig = {
        # Early: restrict the Maono card to input-only (no output sink created)
        "10-maono-alsa" = {
          "monitor.alsa.rules" = [
            {
              matches = [
                { "alsa.card.name" = "Wireless Lavalier Mic"; }
              ];
              actions = {
                "update-props" = {
                  "api.alsa.profile" = "input:analog-mono";
                };
              };
            }
          ];
        };

        # Mid: device priorities. Split by monitor — there is no generic
        # `monitor.rules` section, so the previous single block never applied.
        "50-audio-priority" = {
          "monitor.alsa.rules" = [
            # Lavalier mic (source) — always the highest-priority input
            {
              matches = [
                { "node.name" = "alsa_input.usb-maono_Micro_Wireless_Lavalier_Mic_MCTSN123717-00.pro-input-0"; }
              ];
              actions = {
                "update-props" = {
                  "priority.driver" = 2500;
                  "priority.session" = 2500;
                };
              };
            }
            # Safeguard: hide any Lavalier output sink (regex covers variants)
            {
              matches = [
                { "node.name" = "~alsa_output.usb-maono_Micro_Wireless_Lavalier_Mic_MCTSN123717-00.*"; }
              ];
              actions = {
                "update-props" = {
                  "node.disabled" = true;
                  "priority.driver" = 0;
                  "priority.session" = 0;
                };
              };
            }
            # Laptop speakers — fallback above the defaults, below the EM037
            {
              matches = [
                { "node.name" = "alsa_output.pci-0000_00_1f.3-platform-sof_sdw.HiFi__Speaker__sink"; }
              ];
              actions = {
                "update-props" = {
                  "priority.driver" = 1500;
                  "priority.session" = 1500;
                };
              };
            }
          ];
          "monitor.bluez.rules" = [
            # EM037 headphones — highest priority whenever connected
            {
              matches = [
                { "node.name" = "bluez_output.A9_29_3B_FA_E5_4E.1"; }
                { "node.name" = "bluez_input.A9:29:3B:FA:E5:4E"; }
              ];
              actions = {
                "update-props" = {
                  "priority.driver" = 2000;
                  "priority.session" = 2000;
                };
              };
            }
          ];
        };

        # 0.5 renamed this from the old `default-routes.store`, and settings
        # live under a `wireplumber.settings` section, not at the file's top
        # level — so the previous `settings = { "default-routes.store" = false; }`
        # did nothing. Off on purpose: the speakers expose no hardware volume,
        # so a >100% software boost set once in pavucontrol is pure digital
        # clipping that would otherwise be written to
        # ~/.local/state/wireplumber/default-routes and silently restored on
        # every profile change and reboot. On 2026-08-14 it had persisted a
        # 219% speaker gain exactly this way.
        # Verify with `wpctl settings | grep -A3 restore-routes`.
        "51-no-route-restore" = {
          "wireplumber.settings" = {
            "device.restore-routes" = false;
          };
        };
      };
    };

    # NOTE — deliberately NOT re-enabled, do not "fix" these two:
    #
    # 1. A forced low-latency quantum:
    #      extraConfig.pipewire."99-lowlatency"."context.properties" = {
    #        "default.clock.quantum" = 256; "default.clock.min-quantum" = 256;
    #        "default.clock.max-quantum" = 256;
    #      };
    #    The old version of this never applied (the attr name is the FILENAME,
    #    the section has to be inside the value), which was lucky. This card
    #    runs a 1024-frame / 8192-frame ALSA period and already underruns;
    #    pinning min=max=256 would guarantee dropouts. Leave PipeWire on its
    #    adaptive default (1024, range 32-2048).
    #
    # 2. "session.suspend-timeout-seconds" = 0 on the alsa/bluez nodes.
    #    Intended to stop idle static, but it also removes the suspend/reopen
    #    cycle that is the only way a wedged SOF/SoundWire PCM recovers. See
    #    the xrun wedge of 2026-08-14, where the cure was forcing exactly that
    #    reopen (`wpctl set-profile <card> 0` then `1`).
  };
}
