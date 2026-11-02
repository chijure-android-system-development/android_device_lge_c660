# ---- SoC / CPU ----
TARGET_NO_BOOTLOADER := true
TARGET_BOARD_PLATFORM := msm7k
TARGET_ARCH := arm
TARGET_ARCH_VARIANT := armv6-vfp
TARGET_CPU_VARIANT := generic
TARGET_CPU_ABI := armeabi
TARGET_BOOTLOADER_BOARD_NAME := c660
BOARD_VENDOR := lge
TARGET_ARCH_LOWMEM := true
FORCE_ARM_DEBUGGING := true

TARGET_BOARD_PLATFORM_GPU := qcom-adreno200

# ---- Kernel prebuilt + boot image header ----
TARGET_PREBUILT_KERNEL := device/lge/c660/kernel-recovery-slim

BOARD_KERNEL_CMDLINE := mem=215M console=ttyMSM2,115200n8 androidboot.hardware=muscat
BOARD_KERNEL_BASE := 0x02800000
BOARD_KERNEL_PAGESIZE := 2048

# ---- Partition sizes from /proc/mtd on LG-C660h ----
TARGET_USERIMAGES_USE_EXT4 := false
TARGET_USERIMAGES_USE_UBIFS := false
BOARD_USE_MTDUTILS := true
BOARD_BOOTIMAGE_PARTITION_SIZE := 0x00440000
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 0x00500000
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 0x0cd00000
BOARD_USERDATAIMAGE_PARTITION_SIZE := 0x0b280000
BOARD_FLASH_BLOCK_SIZE := 131072
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := yaffs2
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := yaffs2
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := yaffs2

# ---- Recovery ----
BOARD_HAS_NO_SELECT_BUTTON := true
BOARD_LDPI_RECOVERY := true
BOARD_HAS_JANKY_BACKBUFFER := true
TARGET_RECOVERY_FSTAB := device/lge/c660/recovery.fstab
ifeq ($(TARGET_BUILD_VARIANT), eng)
  BOARD_CUSTOM_BOOTIMG_MK := device/lge/c660/customrecoveryimg.mk
endif

TW_THEME := watch_mdpi
TARGET_RECOVERY_PIXEL_FORMAT := "RGB_565"
TARGET_RECOVERY_FORCE_PIXEL_FORMAT := "RGB_565"
RECOVERY_GRAPHICS_FORCE_USE_LINELENGTH := true

TW_INTERNAL_STORAGE_PATH := "/sdcard"
TW_INTERNAL_STORAGE_MOUNT_POINT := "sdcard"
# the C660 has no internal storage: the microSD is the only storage
BOARD_UMS_LUNFILE := "/sys/devices/platform/usb_mass_storage/lun%d/file"
TW_NO_EXFAT := true
TW_INCLUDE_CRYPTO := false
TW_EXCLUDE_ENCRYPTED_BACKUPS := true
TW_EXCLUDE_MTP := true
TW_EXCLUDE_SUPERSU := true
TW_NO_REBOOT_BOOTLOADER := true
TW_NO_CPU_TEMP := true
TW_DEVICE_VERSION := 0.1
TW_BUILD_AUTHOR := chijure

TW_BRIGHTNESS_PATH := "/sys/class/leds/lcd-backlight/brightness"
TW_SECONDARY_BRIGHTNESS_PATH := "/sys/class/leds/button-backlight/brightness"
TW_MAX_BRIGHTNESS := 255
TW_DEFAULT_BRIGHTNESS := 80
# FBIOBLANK re-inits the ilitek LCD and the first frame after unblank is lost, leaving a stale screen
TW_NO_SCREEN_BLANK := true
# msm_fb only refreshes this command-mode LCD in FBIOPAN_DISPLAY, FBIOPUT_VSCREENINFO alone leaves a stale frame
TW_FBIOPAN := true

BOARD_HAS_LARGE_FILESYSTEM := true
BOARD_VOLD_MAX_PARTITIONS := 12
