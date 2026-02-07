#!/bin/bash
set -e

# 1. Get GPU ID
GPU_ID=$(lspci -nn -d 10de: | grep -E "VGA|3D" | head -n1 | grep -oP '(?<=\[10de:)[0-9a-fA-F]{4}(?=\])')

if [[ -z "$GPU_ID" ]]; then
    echo "No NVIDIA GPU found. Skipping."
    exit 0
fi

echo "[*] Found NVIDIA ID: $GPU_ID"

# 2. Kill the conflicts
echo "[*] Removing conflicting open-driver packages..."
sudo pacman -Rdd --noconfirm libxnvctrl linux-cachyos-nvidia-open linux-cachyos-lts-nvidia-open nvidia-open-dkms 2>/dev/null || true

# 3. Patch the file (Ensure directory exists and handle trailing newlines)
sudo mkdir -p /var/lib/chwd/ids/
if [ ! -f /var/lib/chwd/ids/nvidia-580.ids ]; then sudo touch /var/lib/chwd/ids/nvidia-580.ids; fi

if ! grep -q "$GPU_ID" /var/lib/chwd/ids/nvidia-580.ids; then
    echo "[*] Patching chwd ID list..."
    sudo sh -c "echo '$GPU_ID' >> /var/lib/chwd/ids/nvidia-580.ids"
else
    echo "[*] GPU ID already present in 580 list."
fi

# 4. Remove old profile
echo "[*] Removing old chwd profile..."
sudo chwd -r pci nvidia-open-dkms --noconfirm || true

# 5. Install specific profile (Targeting the 580xx specifically)
echo "[*] Installing 580xx proprietary profile..."
sudo chwd -i pci nvidia-580xx-dkms --noconfirm

# 6. Install VA-API utils
sudo pacman -S --needed --noconfirm libva-utils

# 7. Add NVIDIA environment variables for UWSM
echo "[*] Setting environment variables..."
mkdir -p $HOME/.config/uwsm
cat <<EOF | tee -a $HOME/.config/uwsm/env > /dev/null

# NVIDIA Environment Variables
export LIBVA_DRIVER_NAME=nvidia
export GBM_BACKEND=nvidia-drm
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export NVD_BACKEND=direct
export MOZ_DISABLE_RDD_SANDBOX=1
export CUDA_DISABLE_PERF_BOOST=1
EOF
