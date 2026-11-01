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
