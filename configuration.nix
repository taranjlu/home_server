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
    ];
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
