{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "usb_storage"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # Primary filesystems
  fileSystems."/" = {
    device = "zpool-nixos/root";
    fsType = "zfs";
  };

  fileSystems."/boot" = {
    device = "zpool-nixos/boot";
    fsType = "zfs";
  };

  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-label/ESP_SSD_0";
    fsType = "vfat";
  };

  # Encrypted datasets
  fileSystems."/unlock" = {
    device = "zpool-nixos/root/encrypted/unlock";
    fsType = "zfs";
    neededForBoot = true;
  };

  fileSystems."/nix" = {
    device = "zpool-nixos/root/encrypted/nix";
    fsType = "zfs";
  };

  fileSystems."/home" = {
    device = "zpool-nixos/root/encrypted/home";
    fsType = "zfs";
  };

  fileSystems."/var" = {
    device = "zpool-nixos/root/encrypted/var";
    fsType = "zfs";
  };

  # Other pools and datasets
  fileSystems."/zpool-ssd-raidz1-0" = {
    device = "zpool-ssd-raidz1-0";
    fsType = "zfs";
  };

  fileSystems."/zpool-hdd-raid1-0" = {
    device = "zpool-hdd-raid1-0";
    fsType = "zfs";
  };

  fileSystems."/zpool-hdd-raid1-1" = {
    device = "zpool-hdd-raid1-1";
    fsType = "zfs";
  };

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
