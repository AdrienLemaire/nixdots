{ pkgs, ... }: {
  # GnuPG
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryPackage = pkgs.pinentry-curses;
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
