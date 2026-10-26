# hmos2lemonadep: HarmonyOS 5 on the OnePlus 9 Pro (lemonadep)

A port of [hmos2sweet](https://github.com/tsryzenstech/hmos2sweet) from the Redmi Note 10 Pro (sweet, SM7150)
to the OnePlus 9 Pro (lemonadep, SM8350 "lahaina"). The HarmonyOS userspace is the one hmos2sweet built
(`rom_full43`: Pura 70 OTA `ADY-LGRP3-CHN 205.1.0.128(SP5)`, iteration 43); what changes is everything that
touches the hardware.

## What carries over and what does not

| Part | sweet | lemonadep | State |
|---|---|---|---|
| system, sys_prod, chip_prod, cust, patch | from the OTA | the same images | reused |
| Kernel | LineageOS 4.14 sm6150 + 18 patches | LineageOS 5.4 sm8350 (`lineage-24.0`) + `src/kernel/lemonadep/patches` | patches ported, **not built yet** |
| Boot | Xiaomi ABL, header v2, dtb in boot | OnePlus ABL, header v3, dtb + vendor ramdisk in `vendor_boot`, dtbo separate | to do |
| Kernel modules | few | ~80 vendor modules (display `msm_drm.ko`, audio, haptics, camera, rmnet) | `hmos-preinit` has to load them |
| Display | SDE DRM, 1080x2400 video mode | SDE DRM (techpack/display), AMB670YF01 1440x3216 command mode, LTPO, boot loader leaves FHD+ 1080x2412 | composer VDI should carry over; geometry/dpi/cutout redone |
| GPU | Adreno 618, Mesa freedreno on KGSL | Adreno 660 (KGSL built in), same Mesa; firmware a660_sqe/gmu/zap from the phone's vendor | to check |
| Touch | (in kernel) | Synaptics S3908, OnePlus touch driver in the kernel | to check |
| Coprocessors | sweet-rproc + linux-msm daemons (qrtr, rmtfs, tqftpserv, pd-mapper) | remoteproc (PAS) on 5.4; sensors on the SLPI, not the ADSP | redo |
| Audio | Bolero + 2x aw882xx, tinyalsa VDI | q6/APR + Bolero + WCD938x + 2x TFA98xx (tfa98xx-v6) | VDI carries over, mixer paths and machine driver differ |
| WLAN | WCN3990 (icnss, in kernel) | cnss2 (in kernel) + qcacld-3.0 `wlan.ko` (separate source, not in this tree) | redo |
| Vibration | aw8624 | aw8697 | redo (kernel patch like 0016) |
| NFC, IR, camera, fingerprint | | NFC present, no IR blaster | later |

Kernel patches, sweet -> lemonadep (`src/kernel/lemonadep/patches`):

| sweet | lemonadep |
|---|---|
| 0001 userspace bring-up | 0001 (binder structs are in `binder_internal.h` on 5.4) |
| 0002, 0003 DRM auth/master | 0002 (`DRM_ROOT_ONLY` dropped; 5.4 has no `DRM_UNLOCKED`) |
| 0004-0007 hmdfs/sharefs emulation, fs-verity stub | 0003 (`ksys_mount`, `do_mkdirat`) |
| 0009, 0012, 0015, 0018 binder pid, reboot, memcg | 0004 |
| 0008 firmware paths, 0013 SSR panic | 0005 (`OHOS_FIRMWARE_PATHS`; 5.4 has no `subsystem_restart.c`, `PANIC_ON_SSR_NOTIF_TIMEOUT` off) |
| 0010, 0011, 0014 icnss BDF | not needed: cnss2 downloads the BDF itself |
| 0016 aw8624 vibrator | to do for aw8697 |
| 0017 /sys/nfc | to do once the NFC chip is known |

## Boot plan

```
OnePlus ABL ─► boot.img (header v3, `fastboot boot`: nothing flashed for the first tests)
                ├─ Image (5.4 + patches)
                └─ ramdisk: HarmonyOS ramdisk + hmos-preinit + /hmos/modules (our .ko, modules.load)
               vendor_boot (the phone's own): dtb + vendor ramdisk, appended by ABL before ours
hmos-preinit: loads /hmos/modules in modules.load order, maps the HarmonyOS images, logs, exec init_early
```

The vendor ramdisk of the phone's `vendor_boot` carries the installed Android's modules; they do not match this
kernel, so ours live under `/hmos/modules` and the others are never loaded.

Open decision (the phone's owner): where the HarmonyOS images (about 6.5 GB) and its `/data` live:

1. **Files on `userdata`, mapped by `hmos-preinit`** through loop devices: nothing flashed, boot with
   `fastboot boot` only; Android's `userdata` is reformatted (or the files placed in it).
2. **The B slot of `super`** (`system_b`, ... plus `boot_b`, `vendor_boot_b`, `dtbo_b`): Android stays on slot A;
   `super` is 11.19 GB, so whether both fit has to be measured.
3. **All of `super`** as hmos2sweet does on sweet: Android is gone.

## Building

```sh
build/build_kernel_lemonadep.sh      # -> prebuilt/lemonadep/kernel/{Image,dtb/,modules/,modules.load}
```

## Status (2026-10-26)

- Fork created; kernel tree cloned (LineageOS `android_kernel_oneplus_sm8350`, `lineage-24.0`, `187d13cd3`).
- Patches 0001-0005 ported by hand (none of sweet's applied as they were) and exported. **Not compiled yet.**
- Not started: lemonadep `hmos-preinit` (module loading, image mapping, logging without a `cache` partition),
  boot image builder for header v3, vendor partition patches (display geometry, GPU firmware, audio, rproc).
