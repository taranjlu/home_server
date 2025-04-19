# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "zfs" ];

  # Set zfs arc size
  boot.kernelParams = [
    "zfs.zfs_arc_max=103079215104"
  ];

  # Unlock and mount all ZFS datasets after booting
  systemd.services.zfs-unlock-datasets = {
    description = "Import and unlock ZFS datasets";
    wantedBy = [ "multi-user.target" ];
    after = [
      "zfs.target"
      "local-fs.target"
    ];
    requiredBy = [ "multi-user.target" ];
    path = [ pkgs.zfs ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "zfs-unlock" ''
        zpool import -af || true
        zfs load-key -a || true
        zfs mount -a || true
      '';
    };
  };

  # ZFS specific configurations
  services.zfs = {
    autoScrub.enable = true;
    trim.enable = true;
    autoSnapshot = {
      enable = true;
      frequent = 4; # Keep 4 15-minute snapshots
      hourly = 24; # Keep 24 hourly snapshots
      daily = 7; # Keep 7 daily snapshots
      weekly = 4; # Keep 4 weekly snapshots
      monthly = 12; # Keep 12 monthly snapshots
    };
  };

  # Mirror the primary ESP to the secondary ESP
  systemd.services.mirror-esp = {
    description = "Mirror the primary ESP to the secondary ESP";
    path = with pkgs; [
      mount
      umount
      rsync
    ];

    script = ''
      mkdir -p /boot_mirror
      mount /dev/disk/by-label/ESP_SSD_1 /boot_mirror
      rsync -av --delete /boot/ /boot_mirror/
      umount /boot_mirror
      rmdir /boot_mirror
    '';

    serviceConfig = {
      Type = "oneshot";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  systemd.paths.mirror-esp = {
    description = "Watch /boot/loader/entries for changes to trigger ESP mirroring";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = "/boot/loader/entries";
      Unit = "mirror-esp.service";
    };
  };

  # Enable tailscale service
  services.tailscale = {
    enable = true;
    authKeyFile = "/var/lib/tailscale/${config.networking.hostName}_authkey";
  };

  # Create tailscale directory and placeholder key file
  system.activationScripts.tailscale-auth = ''
    mkdir -p /var/lib/tailscale
    chmod 0700 /var/lib/tailscale

    if [ ! -f /var/lib/tailscale/${config.networking.hostName}_authkey ]; then
      echo "# Replace with your Tailscale auth key" > /var/lib/tailscale/${config.networking.hostName}_authkey
      chmod 0600 /var/lib/tailscale/${config.networking.hostName}_authkey
    fi
  '';

  # Enable Vault for secrets management
  services.vault = {
    enable = true;
    dev = false; # Disable dev mode
    storageBackend = "file";
    storagePath = "/var/lib/vault/data"; # Persistent storage directory
    address = "127.0.0.1:8200"; # Listen address
    extraConfig = ''
      ui = true # Optional: enables the web UI
      api_addr = "http://127.0.0.1:8200" # API address for clients
      cluster_addr = "http://127.0.0.1:8201" # For clustering (not needed here, but required)
    '';
  };

  # Persist encrypted keys (owned by taran for now)
  systemd.tmpfiles.rules = [
    "d /var/lib/vault/data 0700 vault vault - -"
    "f /var/lib/vault/unseal-keys.txt.gpg 0600 root root - -"
  ];

  # Vault unseal script
  # NOTE: Use taran key since that is what was used to encrypt.
  environment.etc."vault-unseal.sh" = {
    text = ''
      #!${pkgs.bash}/bin/bash
      export VAULT_ADDR="http://127.0.0.1:8200"
      export GNUPGHOME="/home/taran/.gnupg"  # Use taran's GPG home
      KEYS="$(${pkgs.gnupg}/bin/gpg --yes --batch --decrypt /var/lib/vault/unseal-keys.txt.gpg)"
      KEY1=$(echo "$KEYS" | grep "Unseal Key 1" | cut -d':' -f2 | tr -d ' ')
      KEY2=$(echo "$KEYS" | grep "Unseal Key 2" | cut -d':' -f2 | tr -d ' ')
      KEY3=$(echo "$KEYS" | grep "Unseal Key 3" | cut -d':' -f2 | tr -d ' ')
      ${pkgs.vault}/bin/vault operator unseal "$KEY1"
      ${pkgs.vault}/bin/vault operator unseal "$KEY2"
      ${pkgs.vault}/bin/vault operator unseal "$KEY3"
    '';
    mode = "0700";
  };

  # Systemd vault unseal service
  systemd.services.vault-unseal = {
    description = "Unseal Vault on Startup";
    after = [ "vault.service" ];
    requires = [ "vault.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [
      pkgs.getent
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/etc/vault-unseal.sh";
      RemainAfterExit = "yes";
      Restart = "on-failure";
      RestartSec = "3s";
    };
    unitConfig = {
      StartLimitIntervalSec = "15s";
      StartLimitBurst = "5";
    };
  };

  # Docker
  virtualisation.docker = {
    enable = true;
    storageDriver = "zfs";
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
    daemon.settings = {
      data-root = "/zpool-ssd-raidz1-0/root/encrypted/containers/docker";
      storage-opts = [
        "zfs.fsname=zpool-ssd-raidz1-0/root/encrypted/containers/docker"
      ];
    };
  };

  # Docker Compose Services
  systemd.services.docker-compose-services = {
    description = "Docker Compose Services";
    after = [
      "docker.service"
      "vault-unseal.service"
    ];
    requires = [
      "docker.service"
      "vault-unseal.service"
    ];
    wantedBy = [ "multi-user.target" ];
    path = [
      pkgs.docker-compose
      pkgs.vault
      pkgs.getent
    ];
    environment = {
      VAULT_ADDR = "http://127.0.0.1:8200";
      VALUT_TOKEN = "/root/.vault-token";
    };

    script = ''
      cd /zpool-ssd-raidz1-0/root/encrypted/containers/docker-compose/compose-files
      services=("immich", "pihole")
      secrets_script=".secrets.sh"
      for service in "''${services[@]}"; do
        if [ -d "$service" ]; then
          cd "$service"
          test -f "$secrets_script" && . "$secrets_script" || echo "Warning: No secrets script not found."
          docker-compose up -d
          cd ..
        else
          echo "Warning: Service directory $service not found"
        fi
      done
    '';

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  # Basic system configuration
  networking = {
    hostName = "guillo";
    hostId = "131867d4";
  };
  time.timeZone = "America/Los_Angeles"; # Adjust this to your timezone

  # Define a user account
  users.users.taran = {
    isNormalUser = true;
    extraGroups = [
      "docker"
      "wheel"
    ];
  };

  # Disable root login
  users.users.root.hashedPassword = "!"; # Locked password

  # Allow specific unfree packages
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "vault"
    ];

  # Basic system packages
  environment.systemPackages = with pkgs; [
    fd
    fish
    ghostty # Add for ghostty terminfo.
    git
    gnupg
    jujutsu
    macchina
    neovim
    pinentry-tty
    pwgen
    ripgrep
    ripgrep-all
    tailscale
    tldr
    tree
    vault
    wget
    zfs
  ];

  # Tell GPG to use pinentry-tty
  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-tty;
  };

  # Enable SSH server
  services.openssh.enable = true;

  system.stateVersion = "24.11";

}
