#!/usr/bin/env fish

# Create key in the needed location
set KEYFILE /unlock/zfskey
echo "Generating ZFS key at $KEYFILE ..."
mkdir -p /unlock
head -c 32 /dev/urandom >"$KEYFILE"
chmod 600 "$KEYFILE"
echo Done

# Use disko to configure disks
echo "Run disko..."
set -l disko_config_path "$(realpath $(dirname $(status -f)))/disko-config.nix"
nix run --extra-experimental-features nix-command --extra-experimental-features flakes github:nix-community/disko/v1.11.0 -- \
    --mode "destroy,format,mount" \
    "$disko_config_path"
echo Done

# Copy the zfskey
echo "Copy /unlock/zfskey -> /mnt/unlock/zfskey"
cp /unlock/zfskey /mnt/unlock/zfskey
echo Done
