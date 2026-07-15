{ pkgs, ... }: {
  # GnuPG
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    # GUI pinentry: curses needs a controlling TTY, which processes spawned
    # inside tmux/Claude Code don't have, so the prompt could never be shown.
    pinentryPackage = pkgs.pinentry-qt;
    # These settings help with passphrase caching
    # in /etc/gnupg/gpg-agent.conf
    settings = {
      default-cache-ttl = 86400; # 1 day
      default-cache-ttl-ssh = 86400; # 1 day
      max-cache-ttl = 86400; # 1 day
      max-cache-ttl-ssh = 86400; # 1 day
    };
  };
}
