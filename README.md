# TWRP Device configuration for LGE C660/C660h

## Device notes

Basic | Spec
-----:|:-----
Codename | muscat / c660
Model tested | LG-C660h
Chipset | Qualcomm MSM7227T / msm7k
CPU ABI | armeabi, armv6-vfp
Display | 240x320, RGB_565
Storage | NAND MTD with YAFFS2 system/data/cache, microSD as `/sdcard`
Stock Android | 2.3.x Gingerbread

Partition sizes were taken from `/proc/mtd` on a connected LG-C660h:

```text
boot      0x00440000
system    0x0cd00000
recovery  0x00500000
cache     0x04000000
userdata  0x0b280000
misc      0x00040000
```

## Build

Use the local TWRP 4.4 Docker environment:

```bash
cd /home/chijure/twrp-4.4-docker
LOCAL_UID=$(id -u) LOCAL_GID=$(id -g) docker compose run --rm twrp-4.4-builder bash
```

Inside the container:

```bash
source build/envsetup.sh
lunch omni_c660-eng
mka recoveryimage
```

The recovery image is expected under:

```text
/home/builder/out/twrp-4.4/target/product/c660/recovery.img
```

## Recovery partition and kernel (5 MB)

`recovery` is an MTD partition of 0x500000 bytes. The full TWRP does not fit with the
stock-recovery kernel (3.2 MB), so the device tree ships a trimmed 2.6.35 kernel:

- `kernel-recovery-slim` (1.95 MB) and the config used to build it,
  `prebuilt/kernel-recovery-slim.config` (source: `android-msm-2.6.35`, built in the
  `cm7-builder` container with `arm-eabi-4.4.3`).
- **Keep `CONFIG_INET=y`.** The Gingerbread `adbd` exits when it cannot open its tcp
  listener, so without INET there is no adb interface at all (USB enumerates, but no
  `ff/42/01` interface).
- `CONFIG_FUSE_FS=y` is required for `adb sideload`.
- The image is about 4.15 MB (4,349,952 bytes), ~0.85 MB free. `bu`, the FAT tools
  (`mkfs.fat`, `fsck.fat`, `fatlabel`) and `pigz` are kept; only `libusbhost` is dropped
  in `customrecoveryimg.mk` (MTP is excluded).

`customrecoveryimg.mk` (eng variant only) also installs `mksh` as `/sbin/sh`, the
Gingerbread `adbd` (this kernel has the legacy `/dev/android_adb`, no FunctionFS) and the
`clearmisc` service.

## Known quirks and why the tree looks like this

| Symptom | Cause | Fix |
|---|---|---|
| `adb` never shows up | KitKat `adbd` expects FunctionFS / `android_usb` class | `prebuilt/adbd` (Gingerbread) + `service adbd /sbin/adbd recovery` |
| Reboot to system ends in recovery | LG's bootloader leaves a flag in `misc` (mtd8); TWRP cannot write the BCB on MTD | `prebuilt/init.clearmisc.rc` runs `erase_image misc` at boot |
| Screen shows a stale frame after the screen timeout (lock screen with the slider at the end, taps seem ignored) | `msm_fb` only refreshes this command-mode LCD in `FBIOPAN_DISPLAY`; `FBIOPUT_VSCREENINFO` alone does not | `TW_FBIOPAN := true`; `TW_NO_SCREEN_BLANK := true` so the LCD is not re-initialised on wake |
| `TW_NO_SCREEN_BLANK` had no effect | the flag did not reach `libminuitwrp` | `patches/0005-minuitwrp-propagate-no-screen-blank.patch` |
| Touch looked broken ("Install" went back to Home) | trimmed ramdisk without `languages/`, not the driver | keep `languages/` and the fonts (touch panel is `touch_mcs6000`, old MT protocol, 240x320 = screen) |
| Android build does not rebuild after changing flags | KitKat build system does not track `LOCAL_CFLAGS` | delete `obj/SHARED_LIBRARIES/libminuitwrp_intermediates` and `obj/EXECUTABLES/recovery_intermediates`, then check that `recovery.img` md5 changes |
| `TW_BUILD_AUTHOR := chijure` overlaps the clock in the title bar | the 240 px watch theme has no room for `TWRP 3.1.1-0.1 by chijure`; `placement="5"` centres on the screen and ignores `x` | `customrecoveryimg.mk` right-aligns the clock (`placement="1"`) and shortens the English `Battery:` label to `Bat:` |
| `adb sideload` ends with "Complete Failed" (`open /dev/fuse: No such file or directory` in the log) | TWRP serves the zip through FUSE (`fuse_sideload`) and the recovery kernel had `CONFIG_FUSE_FS` off (it is off in the CM7 kernel too) | `CONFIG_FUSE_FS=y` in `prebuilt/kernel-recovery-slim.config` (+25 KB) |
| LUN stays bound after "Unmount" in USB storage mode | `usb_storage_disable()` writes an empty string, a 0-byte write never reaches the sysfs `store()` | `patches/0006-usb-storage-disable-write-newline.patch` |

The patches under `patches/` apply to `bootable/recovery` (it is not a git checkout here, so
reapply them after a resync).

## Storage and USB

- The C660 has no internal storage: the microSD (`/dev/block/mmcblk0p1`) is the only storage.
  `/sd-ext` is not in `recovery.fstab`.
- MTP is not available with the recovery kernel above (`USB_ANDROID_MTP` and `FUNCTIONFS`
  are off). USB mass storage works through the legacy gadget:
  `BOARD_UMS_LUNFILE := /sys/devices/platform/usb_mass_storage/lun%d/file`
  (Mount > storage > *Mount USB Storage*).
- Unmount the card on the PC before pressing *Unmount* on the phone.

## Flashing and testing from a running recovery

```bash
adb push recovery.img /tmp/r.img
adb shell flash_image recovery /tmp/r.img        # from CM7 use /data/local/tmp
adb shell dump_image recovery /tmp/rb.img        # pull and compare with the file
adb reboot recovery
```

`/tmp` is a tmpfs and is emptied on every reboot. TWRP has no `getevent`, `dmesg` or `logcat`;
the static busybox of the CWM ramdisk, pushed as `/tmp/busybox`, provides `dmesg`, `od`, `dd`.
Recovery entry: Vol- + Home + Power.
