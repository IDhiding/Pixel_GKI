#!/bin/bash
info() {
  tput setaf 3  
  echo "[INFO] $1"
  tput sgr0
}

# Setting
# Android Version
export ANDROID_VER="14"
# Kernel Version
export KERNEL_VER="6.1"
# Security Patch
export SEC_PATCH="2025-05"
# Kernel Suffix
export KERNEL_NAME="-android14-11-g9a32439e14e9-ab13050921"
# System Time
export BUILD_TIME="2025-05-27 00:12:14 UTC"

info "Modify the script before starting"
info "Android Version：Android ${ANDROID_VER}"
info "Kernel Version：${KERNEL_VER}"
info "Security Patch：${SEC_PATCH}"
info "Kernel Suffix：${KERNEL_NAME}"
info "Build Time：${BUILD_TIME}"
info "After startup, press Ctrl+C to exit"

read -n 1 -s -p "Press any key to continue"
echo

# Setup for KPM
while true; do
  read -p "KPM Feature (1=Enable, 0=Disable): " kpm
  if [[ "$kpm" == "0" || "$kpm" == "1" ]]; then
    export KERNEL_KPM="$kpm"
    break
  else
    info "Error Please select：0 or 1"
  fi
done

#Download Toolkit
info "Install Toolkit"
sudo apt update && sudo apt upgrade -y
sudo apt-get install -y build-essential bc bison python3 curl git zip wget

#Git for GKI
git config --global user.name "hiding"
git config --global user.email "hiding@hotmail.com"

#Download Repo
info "Install repo"
curl https://storage.googleapis.com/git-repo-downloads/repo > $HOME/Pixel_GKI/repo
chmod a+x $HOME/Pixel_GKI/repo
sudo mv $HOME/Pixel_GKI/repo /usr/local/bin/repo

#Sync Generic Kernel Image Source Code
info "Sync GKI source code"
mkdir build_kernel && cd build_kernel
repo init -u https://android.googlesource.com/kernel/manifest -b common-android$ANDROID_VER-$KERNEL_VER-$SEC_PATCH --depth=1
repo sync

#Download SukiSU-Ultra
info "Setup SukiSU-Ultra"
curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s susfs-dev
cd ./KernelSU
KSU_VERSION=$(expr $(/usr/bin/git rev-list --count main) "+" 10606)
echo "KSUVER=$KSU_VERSION" >> .env
source .env
export KSU_VERSION=$KSU_VERSION
sed -i "s/DKSU_VERSION=12800/DKSU_VERSION=${KSU_VERSION}/" kernel/Makefile

#Download SUSFS
info "Setup SUSFS & SukiSU Patch"
cd $HOME/Pixel_GKI/build_kernel
git clone https://gitlab.com/simonpunk/susfs4ksu.git -b gki-android$ANDROID_VER-$KERNEL_VER
git clone https://github.com/SukiSU-Ultra/SukiSU_patch.git
cp susfs4ksu/kernel_patches/50_add_susfs_in_gki-android$ANDROID_VER-$KERNEL_VER.patch ./common/
cp susfs4ksu/kernel_patches/fs/* ./common/fs/
cp susfs4ksu/kernel_patches/include/linux/* ./common/include/linux/
cd common
sed -i 's/-32,12 +32,38/-32,11 +32,37/g' 50_add_susfs_in_gki-android$ANDROID_VER-$KERNEL_VER.patch
sed -i '/#include <trace\/hooks\/fs.h>/d' 50_add_susfs_in_gki-android$ANDROID_VER-$KERNEL_VER.patch
patch -p1 < 50_add_susfs_in_gki-android$ANDROID_VER-$KERNEL_VER.patch || true
cp ../SukiSU_patch/hooks/syscall_hooks.patch ./
patch -p1 -F 3 < syscall_hooks.patch
info "Complete"

#Add these configuration to kernel
info "Add susfs configuration to kernel"
cd $HOME/Pixel_GKI/build_kernel

CONFIGS=(
  "CONFIG_KSU=y"
  "CONFIG_KSU_SUSFS_SUS_SU=n"
  "CONFIG_KSU_MANUAL_HOOK=y"
  "CONFIG_KSU_SUSFS=y"
  "CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y"
  "CONFIG_KSU_SUSFS_SUS_PATH=y"
  "CONFIG_KSU_SUSFS_SUS_MOUNT=y"
  "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y"
  "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y"
  "CONFIG_KSU_SUSFS_SUS_KSTAT=y"
  "CONFIG_KSU_SUSFS_SUS_OVERLAYFS=n"
  "CONFIG_KSU_SUSFS_TRY_UMOUNT=y"
  "CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT=y"
  "CONFIG_KSU_SUSFS_SPOOF_UNAME=y"
  "CONFIG_KSU_SUSFS_ENABLE_LOG=y"
  "CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y"
  "CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y"
  "CONFIG_KSU_SUSFS_OPEN_REDIRECT=y"
)

for CONFIG in "${CONFIGS[@]}"; do
  echo "$CONFIG" >> common/arch/arm64/configs/gki_defconfig
done
info "Complete"

sudo sed -i 's/check_defconfig//' common/build.config.gki
cd common
git add -A && git commit -a -m "BUILD Kernel"

# KPM features
if [ "$KERNEL_KPM" = "1" ]; then
  info "Setup KPM"
  cd $HOME/Pixel_GKI/build_kernel
  
  # Add KPM config
  echo "CONFIG_KPM=y" >> common/arch/arm64/configs/gki_defconfig
  sudo sed -i 's/check_defconfig//' common/build.config.gki
  cd common
  git add -A && git commit -a -m "BUILD Kernel"
  info "Added KPM config"
else
  info "KPM features is disable"
fi

# Add kernel Suffix
cd $HOME/Pixel_GKI/build_kernel || exit
sed -i 's/res="\$res\$(cat "\$file")"/res="-android14-11-g9a32439e14e9-ab13050921"/g' ./common/scripts/setlocalversion
sudo sed -i "s/-android14-11-g9a32439e14e9-ab13050921/$KERNEL_NAME/g" ./common/scripts/setlocalversion

#Unix timestamp converter
info "Set kernel build time"
SOURCE_DATE_EPOCH=$(date -d "$BUILD_TIME" +%s)
export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}
info "${BUILD_TIME}" 

# Build kernel
cd $HOME/Pixel_GKI/build_kernel || exit
info "Building kernel"
sed -i '/^[[:space:]]*"protected_exports_list"[[:space:]]*:[[:space:]]*"android\/abi_gki_protected_exports_aarch64",$/d' ./common/BUILD.bazel
rm -rf ./common/android/abi_gki_protected_exports_*
tools/bazel run --config=fast --config=stamp --lto=thin //common:kernel_aarch64_dist -- --dist_dir=dist

# KPM patching
if [ "$KERNEL_KPM" = "1" ]; then
  info "Patching Image file..."
  cd dist
  curl -LSs "https://raw.githubusercontent.com/ShirkNeko/SukiSU_patch/refs/heads/main/kpm/patch_linux" -o patch
  chmod 777 patch
  ./patch
  rm -rf Image
  mv oImage kernel
  info "Added KPM feature"
else
  info "KPM not Patched"
  mv dist/Image dist/kernel
fi

info "Compilation successful"
info "The kernel is in Pixel_GKI/build_kernel/dist"
info "Use magiskboot repack to boot.img"
