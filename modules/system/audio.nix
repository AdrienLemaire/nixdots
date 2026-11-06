{ inputs, pkgs, ... }: {
  services.pipewire = {
    enable = true;
    audio.enable = true;  # RTKit for real-time priority (reduces crackles on XPS)
    package = inputs.older-pipewire.legacyPackages.${pkgs.stdenv.hostPlatform.system}.pipewire;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber = {
      enable = true;
      package = inputs.older-pipewire.legacyPackages.${pkgs.stdenv.hostPlatform.system}.wireplumber;
      extraConfig = {
        # Early: Restrict Maono card to input-only (no output sink created via ALSA profile)
        "10-maono-alsa" = {
          monitor.alsa.rules = [
            {
              matches = [
                {
                  alsa.card.name = "Wireless Lavalier Mic";
                }
              ];
              actions = {
                "update-props" = {
                  "api.alsa.profile" = "input:analog-mono";  # Forces input-only; disables output creation
                };
              };
            }
          ];
        };
        # Mid: Node priority rules for the lavalier and the laptop speakers.
        # See the INERT note inside -- none of these currently apply.
        "50-audio-priority" = {
          monitor.rules = [
            # NOTE (2026-09-02): every rule in this section is currently INERT.
            # The key is `monitor.rules`, but WirePlumber only reads the
            # per-monitor keys -- `monitor.alsa.rules` / `monitor.bluez.rules`,
            # as used by the "10-maono-alsa" and "99-disable-suspension"
            # sections above and below. Confirmed against the live daemon:
            # the speaker sits at priority.session 712 (rule asks 1500), the
            # lavalier output sink at 1009 (rule asks 0 + disabled), and the
            # lavalier input at 2000 (rule asks 2500). Left as-is deliberately:
            # repairing the key would activate four dormant rules at once,
            # which is a behaviour change, not a cleanup. If you do fix it, note
            # the lavalier input match is ALSO wrong -- the real node is
            # ...-00.mono-fallback, not ...-00.pro-input-0 -- and re-check the
            # speaker's 1500 against the "Speakers (Loud)" sink priority below.
            #
            # The EM037 rule that used to head this list was removed: that
            # headset is no longer even paired (bluetoothctl lists only the
            # MX Keys Mini, Pebble K380s, soundcore Space One, Pebble M350s and
            # P10), so it matched nothing regardless of the key bug.
            #
            # Lavalier Mic (Source) - ALWAYS highest input priority when connected
            {
              matches = [
                { node.name = "alsa_input.usb-maono_Micro_Wireless_Lavalier_Mic_MCTSN123717-00.pro-input-0"; }
              ];
              actions = {
                "update-props" = {
                  priority.driver = 2500;
                  priority.session = 2500;
                };
              };
            }
            # Safeguard: Hide/disable any Lavalier output sink (regex for variants)
            {
              matches = [
                { node.name = "~alsa_output.usb-maono_Micro_Wireless_Lavalier_Mic_MCTSN123717-00.*"; }
              ];
              actions = {
                "update-props" = {
                  "node.disabled" = true;  # Hides from selection/default
                  priority.driver = 0;
                  priority.session = 0;
                };
              };
            }
            # Boost Laptop Speakers (Sink) - medium priority fallback (above any defaults, below EM037)
            {
              matches = [
                { node.name = "alsa_output.pci-0000_00_1f.3-platform-sof_sdw.HiFi__Speaker__sink"; }
              ];
              actions = {
                "update-props" = {
                  priority.driver = 1500;
                  priority.session = 1500;
                };
              };
            }
          ];
        };
        # NOTE: an unquoted dotted key (`monitor.alsa.rules`, `node.name`)
        # becomes a nested object in the generated SPA-JSON, which WirePlumber
        # ignores -- so 10-maono-alsa, 50-audio-priority and
        # 99-disable-suspension have no effect on the live daemon. Quote the
        # keys in any new rule.
        # Late: Disable suspension to prevent static noise on XPS/Intel
        "99-disable-suspension" = {
          monitor.alsa.rules = [
            {
              matches = [
                { node.name = "~alsa_input.*"; }
                { node.name = "~alsa_output.*"; }
              ];
              actions = {
                "update-props" = {
                  "session.suspend-timeout-seconds" = 0;
                };
              };
            }
          ];
          monitor.bluez.rules = [
            {
              matches = [
                { node.name = "~bluez_input.*"; }
                { node.name = "~bluez_output.*"; }
              ];
              actions = {
                "update-props" = {
                  "session.suspend-timeout-seconds" = 0;
                };
              };
            }
          ];
        };
        settings = {
          "default-routes.store" = false;
        };
      };
    };

    # Audio optimization for XPS 13 Plus using drop-in configuration
    #
    # REMOVED (2026-09-02), do not re-add: a forced low-latency quantum,
    #   "context.properties" = { "default.clock.quantum"     = 256;
    #                            "default.clock.min-quantum" = 256;
    #                            "default.clock.max-quantum" = 256; };
    # It never took effect -- the attribute name is the drop-in FILENAME, so it
    # emitted /etc/pipewire/pipewire.conf.d/context.properties.conf as a bare
    # top-level JSON object with no context.properties section, which PipeWire
    # ignores (live daemon ran the adaptive defaults: quantum 1024, min 32,
    # max 2048). That was lucky: this card runs a 1024/8192-frame ALSA period
    # and already underruns under load, so pinning min=max=256 to a 5.3 ms
    # deadline would guarantee the dropouts it looked like it was preventing.
    # Deleted rather than left commented-out precisely because "correcting" the
    # Nix syntax would silently arm it. The rate was 48000 either way.
    extraConfig.pipewire = {
      # Floor the graph quantum at the card's ALSA period (1024 frames, 21 ms).
      # Low-latency clients -- pavucontrol's level meters above all -- pull the
      # quantum down to 256 (5.3 ms), and the sof_sdw PCMs cannot keep that
      # deadline: whichever node drives (speaker, mic, HDMI) runs 8-76 ms late,
      # the speaker loops on "snd_pcm_avail after recover: Broken pipe" and
      # all playback stalls. Every incident (2026-10-25..29) ran at 256;
      # forcing 1024 live with pavucontrol open stopped the errors at once.
      "92-min-quantum" = {
        "context.properties" = {
          "default.clock.min-quantum" = 1024;
        };
      };
      # Loudness chain for the built-in speakers.
      #
      # The rt1316 smart-amp path has NO headroom left: every hardware gain
      # (Speaker, rt1316-* DAC, PGA*.* Master) already sits at 0.00 dB / 100%,
      # so 100% really is as loud as the hardware goes. The only remaining gain
      # is digital, and raising the volume ceiling past 100% just clips, because
      # streaming audio is already normalised near full scale.
      #
      # So compress instead: sc4 lifts the *average* level (that is what the ear
      # reads as loudness) and fastLookaheadLimiter brick-walls the peaks at
      # -1 dB so nothing clips or over-drives the drivers. 100% is genuinely
      # loud and the whole 0-100 range stays usable for tweaking.
      #
      # NOTE: the attribute name is the drop-in FILENAME and the section has to
      # live inside the value -- hence "99-speakers-loud" wrapping a
      # "context.modules" key, not a bare "context.modules" attribute. See the
      # REMOVED quantum note above for what the other spelling does: it emits a
      # bare top-level JSON object that PipeWire silently ignores. Getting this
      # wrong here would mean no sink and no error.
      #
      # Speakers only: playback is pinned to the internal speaker node, so the
      # Bluetooth headset and HDMI outs are untouched. priority.session 1600
      # beats the raw speaker (712 today) and stays ahead of the 1500 the
      # dormant "50-audio-priority" speaker rule would apply if that section's
      # key bug is ever fixed -- otherwise the raw sink would outrank this one
      # and silently bypass the whole chain. Still below a connected headset,
      # so Bluetooth continues to win automatically.
      # Verified against the live daemon before committing: both plugins open
      # and both links resolve (spa.filter-graph "successfully opened").
      "99-speakers-loud" = {
        "context.modules" = [{
          name = "libpipewire-module-filter-chain";
          args = {
            "node.description" = "Speakers (Loud)";
            "media.name" = "Speakers (Loud)";
            "filter.graph" = {
              # LV2, NOT LADSPA. These are the same two Steve Harris plugins
              # either way, but the pinned pipewire (older-pipewire, 1.4.1 --
              # note the CLI on PATH is 1.6.5, which misleads) cannot load them
              # over LADSPA: its ladspa_plugin.c fails with "failed to load
              # plugin 'sc4_1882': No such file or directory" even when handed
              # a valid absolute path to the .so, with every dependency
              # resolving under ldd. The same config loads fine on 1.6.5, so it
              # is a 1.4.1 loader bug. The LV2 backend works on 1.4.1.
              # If the pipewire pin is ever dropped, LADSPA becomes an option
              # again -- but there is no reason to switch back.
              nodes = [
                {
                  type = "lv2";
                  name = "compressor";
                  plugin = "http://plugin.org.uk/swh-plugins/sc4";
                  # Threshold/ratio do the compressing; makeup_gain is the knob
                  # to turn if you want it louder still (max 24 dB, but past
                  # ~16 the limiter starts working hard and it gets squashed).
                  # Port names are LV2 symbols, not the human-readable labels.
                  control = {
                    "rms_peak" = 0.0;
                    "attack" = 10.0;
                    "release" = 150.0;
                    "threshold" = -20.0;
                    "ratio" = 4.0;
                    "knee" = 3.0;
                    "makeup_gain" = 12.0;
                  };
                }
                {
                  type = "lv2";
                  name = "limiter";
                  plugin = "http://plugin.org.uk/swh-plugins/fastLookaheadLimiter";
                  control = {
                    "ingain" = 0.0;
                    "limit" = -1.0;
                    "release" = 0.05;
                  };
                }
              ];
              links = [
                { output = "compressor:left_out"; input = "limiter:in_1"; }
                { output = "compressor:right_out"; input = "limiter:in_2"; }
              ];
              # inputs/outputs deliberately omitted: the graph's unconnected
              # ports are exactly the two compressor inputs and the two limiter
              # outputs, which is what we want (confirmed: n_default_inputs 2,
              # n_default_outputs 2).
            };
            "capture.props" = {
              "node.name" = "effect_input.speakers_loud";
              "media.class" = "Audio/Sink";
              "audio.channels" = 2;
              "audio.position" = [ "FL" "FR" ];
              "priority.session" = 1600;
            };
            "playback.props" = {
              "node.name" = "effect_output.speakers_loud";
              "node.passive" = true;
              "target.object" =
                "alsa_output.pci-0000_00_1f.3-platform-sof_sdw.HiFi__Speaker__sink";
              "audio.channels" = 2;
              "audio.position" = [ "FL" "FR" ];
            };
          };
        }];
      };
    };

    # sc4 + fastLookaheadLimiter live here (the LV2 build of swh-plugins).
    # 55 MB closure, versus several hundred for lsp-plugins, for the same two
    # filters. This sets LV2_PATH on the pipewire user unit.
    extraLv2Packages = [ pkgs.swh_lv2 ];
  };
}
