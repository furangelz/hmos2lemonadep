#!/bin/bash
# Kernel for lemonadep (OnePlus 9 Pro, SM8350 "lahaina"): LineageOS android_kernel_oneplus_sm8350
# (lineage-24.0, Linux 5.4) + src/kernel/lemonadep/patches.
# Output: prebuilt/lemonadep/kernel/{Image, dtb/*.dtb, modules/*.ko, modules.load}
# Needs: clang/lld (LLVM 15+), aarch64-linux-gnu- binutils, python3. Without arm-linux-gnueabi- the
# 32-bit compat vDSO is left out, which nothing on HarmonyOS needs.
set -e
. "$(dirname "$0")/env.sh"
: "${LEMON_KERNEL:=$WORK/android_kernel_oneplus_sm8350}"
BASE=187d13cd3   # "Merge remote-tracking branch 'sm8350/lineage-20' into lineage-23.2" on lineage-24.0
if [ ! -d "$LEMON_KERNEL/.git" ]; then
  git clone -b lineage-24.0 https://github.com/LineageOS/android_kernel_oneplus_sm8350 "$LEMON_KERNEL"
fi
cd "$LEMON_KERNEL"
if [ "$(git rev-parse --abbrev-ref HEAD)" != hmos2lemonadep ]; then
  git checkout -B hmos2lemonadep "$BASE"
  git am "$REPO"/src/kernel/lemonadep/patches/*.patch
fi
M="O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 CROSS_COMPILE=aarch64-linux-gnu-"
make $M vendor/lahaina-qgki_defconfig vendor/ohos.config
make $M -j"$(nproc)" Image modules dtbs
OUT="$REPO/prebuilt/lemonadep/kernel"
rm -rf "$OUT" && mkdir -p "$OUT/dtb" "$OUT/modules"
cp out/arch/arm64/boot/Image "$OUT/"
find out/arch/arm64/boot/dts -name '*.dtb' -exec cp {} "$OUT/dtb/" \;
make $M modules_install INSTALL_MOD_PATH="$OUT/staging" INSTALL_MOD_STRIP=1 >/dev/null
find "$OUT/staging" -name '*.ko' -exec cp {} "$OUT/modules/" \;
rm -rf "$OUT/staging"
# the order Lineage loads them in (device/oneplus/sm8350-common/modules.load), kept as shipped
cp "$REPO/src/kernel/lemonadep/modules.load" "$OUT/"
echo "kernel -> prebuilt/lemonadep/kernel"
