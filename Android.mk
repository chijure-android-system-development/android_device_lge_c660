# Android.mk for the LGE C660/C660h TWRP device tree.
#
# Keep this tree recovery-only. The original CyanogenMod tree includes ROM HALs
# that are not needed for TWRP and do not belong in this Omni 4.4 recovery build.
LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := lge_c660
LOCAL_MODULE_TAGS := optional
include $(BUILD_PHONY_PACKAGE)
