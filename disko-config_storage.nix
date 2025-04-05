{
  disko.devices =
    let
      ssdPartitions0 = {
        zfs = {
          size = "100%";
          content.type = "zfs";
          content.pool = "zpool-ssd-raidz1-0";
        };
      };

      hddPartitions0 = {
        zfs = {
          size = "100%";
          content.type = "zfs";
          content.pool = "zpool-hdd-raid1-0";
        };
      };

      hddPartitions1 = {
        zfs = {
          size = "100%";
          content.type = "zfs";
          content.pool = "zpool-hdd-raid1-1";
        };
      };
    in
    {
      disk = {
        # SSD raidz1 (2TBx3)
        ssd2 = {
          device = "/dev/disk/by-id/ata-WD_Blue_SA510_2.5_2TB_24226V4A0905";
          type = "disk";
          content = {
            type = "gpt";
            partitions = ssdPartitions0;
          };
        };
        ssd3 = {
          device = "/dev/disk/by-id/ata-WD_Blue_SA510_2.5_2TB_24332F4A0103";
          type = "disk";
          content = {
            type = "gpt";
            partitions = ssdPartitions0;
          };
        };
        ssd4 = {
          device = "/dev/disk/by-id/ata-WD_Blue_SA510_2.5_2TB_24332F4A3109";
          type = "disk";
          content = {
            type = "gpt";
            partitions = ssdPartitions0;
          };
        };

        # HDD raid1 (16TBx2)
        hdd0 = {
          device = "/dev/disk/by-id/ata-ST16000NE000-3UN101_ZVT86QY1";
          type = "disk";
          content = {
            type = "gpt";
            partitions = hddPartitions0;
          };
        };
        hdd1 = {
          device = "/dev/disk/by-id/ata-ST16000NE000-3UN101_ZVTE1E8D";
          type = "disk";
          content = {
            type = "gpt";
            partitions = hddPartitions0;
          };
        };

        # HDD raid1 (4TBx2)
        hdd2 = {
          device = "/dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K4UFJNE7";
          type = "disk";
          content = {
            type = "gpt";
            partitions = hddPartitions1;
          };
        };
        hdd3 = {
          device = "/dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K4ZSN84D";
          type = "disk";
          content = {
            type = "gpt";
            partitions = hddPartitions1;
          };
        };
      };

      zpool = {
        # Fast storage for VMs and containers
        zpool-ssd-raidz1-0 = {
          type = "zpool";
          mode = "raidz1";
          options = {
            ashift = "12";
          };
          datasets = {
            "root" = {
              # NOTE: Don't encrypt root dataset directly to allow flexibility later.
              type = "zfs_fs";
            };
            "root/encrypted" = {
              type = "zfs_fs";
              options = {
                encryption = "aes-256-gcm";
                keyformat = "raw";
                keylocation = "file:///unlock/zfskey";
              };
            };
            "root/encrypted/containers" = {
              type = "zfs_fs";
              options = {
                recordsize = "16K";
                compression = "zstd";
              };
            };
            "root/encrypted/containers/docker" = {
              type = "zfs_fs";
            };
            "root/encrypted/vms" = {
              type = "zfs_fs";
              options = {
                recordsize = "8K";
                compression = "zstd";
              };
            };
          };
        };

        # Large storage (16TBx2)
        zpool-hdd-raid1-0 = {
          type = "zpool";
          mode = "mirror";
          options = {
            ashift = "12";
          };
          datasets = {
            "root" = {
              # NOTE: Don't encrypt root dataset directly to allow flexibility later.
              type = "zfs_fs";
            };
            "root/encrypted" = {
              type = "zfs_fs";
              options = {
                encryption = "aes-256-gcm";
                keyformat = "raw";
                keylocation = "file:///unlock/zfskey";
              };
            };
            "root/encrypted/jellyfin" = {
              type = "zfs_fs";
              options = {
                recordsize = "1M";
                compression = "zstd";
              };
            };
            "root/encrypted/immich" = {
              type = "zfs_fs";
              options = {
                recordsize = "1M";
                compression = "zstd";
              };
            };
            "root/encrypted/nextcloud-large-files" = {
              type = "zfs_fs";
              options = {
                recordsize = "1M";
                compression = "zstd";
                xattr = "sa"; # TODO: Why is this needed?
              };
            };
          };
        };

        # Large storage (4TBx2)
        zpool-hdd-raid1-1 = {
          type = "zpool";
          mode = "mirror";
          options = {
            ashift = "12";
          };
          datasets = {
            "root" = {
              # NOTE: Don't encrypt root dataset directly to allow flexibility later.
              type = "zfs_fs";
            };
            "root/encrypted" = {
              type = "zfs_fs";
              options = {
                encryption = "aes-256-gcm";
                keyformat = "raw";
                keylocation = "file:///unlock/zfskey";
              };
            };
            "root/encrypted/nextcloud-small-files" = {
              type = "zfs_fs";
              options = {
                recordsize = "16K";
                compression = "zstd";
                xattr = "sa"; # TODO: Why is this needed?
              };
            };
          };
        };
      };
    };
}
