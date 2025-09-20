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
        # Mid: Node rules for EM037 and lavalier input (as before)
        "50-audio-priority" = {
          monitor.rules = [
            # EM037 Headphone Output (Sink) & Mic (Source) - high priority when connected
            {
              matches = [
                { node.name = "bluez_output.A9_29_3B_FA_E5_4E.1"; }
                { node.name = "bluez_input.A9:29:3B:FA:E5:4E"; }
              ];
              actions = {
                "update-props" = {
                  priority.driver = 2000;
                  priority.session = 2000;
                };
              };
            }
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
    extraConfig.pipewire = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 256;
        "default.clock.min-quantum" = 256;
        "default.clock.max-quantum" = 256;
      };
    };
  };
}
