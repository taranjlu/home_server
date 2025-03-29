{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ./hardware-configuration.nix ];

  # Boot configuration
  boot = {
    supportedFilesystems = [ "zfs" ];
    zfs = {
      package = pkgs.zfs_unstable;
      forceImportAll = true;
      devNodes = "/dev/disk/by-id";
    };

    # Use GRUB instead of systemd-boot
    loader = {
      systemd-boot.enable = false;
      efi.canTouchEfiVariables = true;
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        zfsSupport = true;
      };
    };

    # ZFS unlock sequence
    initrd = {
      postDeviceCommands = ''
        zfs load-key zpool-nixos/root/encrypted
        zfs mount zpool-nixos/root
        zfs mount zpool-nixos/boot
        zfs mount zpool-nixos/root/encrypted/unlock
      '';
      postMountCommands = ''
        zfs load-key -L file:///mnt/unlock/zfskey -a
        zfs mount -a
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
      "wheel"
      "zfs"
    ]; # Enable 'sudo' and ZFS management
  };

  # Basic system packages
  environment.systemPackages = with pkgs; [
    neovim
    wget
    zfs
  ];

  # Enable SSH server
  services.openssh.enable = true;

  system.stateVersion = "24.11";
}
