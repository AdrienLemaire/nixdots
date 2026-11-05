{ pkgs, ... }: {
  # GnuPG
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    # GUI pinentry: curses needs a controlling TTY, which processes spawned
    # inside tmux/Claude Code don't have, so the prompt could never be shown.
    pinentryPackage = pkgs.pinentry-qt;
    # Written to /etc/gnupg/gpg-agent.conf.
    settings = {
      default-cache-ttl = 86400; # 1 day idle
      default-cache-ttl-ssh = 86400; # 1 day idle
      # Also caps passphrases preset by pam_gnupg: unattended agent commits keep
      # signing for a week after the last login or unlock.
      max-cache-ttl = 604800; # 7 days
      max-cache-ttl-ssh = 86400; # 1 day
      # Empty string: a bool renders "allow-preset-passphrase true", which gpg-agent rejects.
      allow-preset-passphrase = "";
    };
  };

  # pam_gnupg: the login password (same as the GPG passphrase) unlocks the key
  # at login and at every screen unlock, so signing never waits on a pinentry.
  security.pam.services.login.gnupg.enable = true; # sddm includes login
  # hyprlock falls back to "su" without its own service; declare it to add the hook.
  security.pam.services.hyprlock.gnupg.enable = true;

  # Keygrips pam_gnupg unlocks (gpg -K --with-keygrip): signing key, encryption subkey.
  home-manager.users.dori.home.file.".pam-gnupg".text = ''
    8B6402E3098502F73D16852E670E1AC0563427A8
    35E311985F25936C33A4D7DBF2D2A51AF68B4409
  '';
}
