# device.mk for a minimal TWRP build on the LGE C660/C660h.

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery.fstab:recovery/root/etc/recovery.fstab \
    $(LOCAL_PATH)/ueventd.muscat.rc:recovery/root/ueventd.muscat.rc

PRODUCT_DEVICE := c660
PRODUCT_NAME := omni_c660
PRODUCT_BRAND := lge
PRODUCT_MODEL := LG-C660h
PRODUCT_MANUFACTURER := LGE
