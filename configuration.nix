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

  # Docker
  virtualisation.docker = {
    enable = true;
    storageDriver = "zfs";
    daemon.settings = {
      data-root = "/zpool-ssd-raidz1-0/root/encrypted/containers/docker";
      storage-opts = [
        "zfs.fsname=zpool-ssd-raidz1-0/root/encrypted/containers/docker"
      ];
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

  # Basic system packages
  environment.systemPackages = with pkgs; [
    fd
    fish
    git
    jujutsu
    macchina
    neovim
    pwgen
    ripgrep
    tldr
    tree
    wget
    zfs
  ];

  # Enable SSH server
  services.openssh.enable = true;

  system.stateVersion = "24.11";

}
