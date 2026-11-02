CL_GRN := "\033[32m"
PRT_IMG := $(CL_GRN)
CL_RST := "\033[0m"

$(INSTALLED_RECOVERYIMAGE_TARGET): $(MKBOOTIMG) \
        $(recovery_uncompressed_ramdisk) \
        $(recovery_ramdisk) \
        $(recovery_kernel)
	@echo -e ${PRT_IMG}"----- Pruning c660 recovery ramdisk ------"${CL_RST}
	$(hide) rm -f \
		$(TARGET_RECOVERY_ROOT_OUT)/etc/mke2fs.conf \
		$(TARGET_RECOVERY_ROOT_OUT)/sbin/e2fsck \
		$(TARGET_RECOVERY_ROOT_OUT)/sbin/listxattr \
		$(TARGET_RECOVERY_ROOT_OUT)/sbin/me.twrp.twrpapp.apk \
		$(TARGET_RECOVERY_ROOT_OUT)/sbin/mke2fs \
		$(TARGET_RECOVERY_ROOT_OUT)/sbin/resize2fs \
		$(TARGET_RECOVERY_ROOT_OUT)/sbin/sgdisk \
		$(TARGET_RECOVERY_ROOT_OUT)/sbin/simg2img \
		$(TARGET_RECOVERY_ROOT_OUT)/sbin/tune2fs \
		$(TARGET_RECOVERY_ROOT_OUT)/sbin/libext2*.so
	$(hide) find $(TARGET_RECOVERY_ROOT_OUT)/sbin -type l | while read link; do \
		target=$$(readlink "$$link"); \
		if [ "$$target" = "busybox" ] || [ "$$target" = "/sbin/busybox" ]; then rm -f "$$link"; fi; \
	done
	$(hide) rm -f $(TARGET_RECOVERY_ROOT_OUT)/sbin/busybox
	@echo -e ${PRT_IMG}"----- Installing mksh as /sbin/sh (busybox is too big to keep) ------"${CL_RST}
	$(hide) cp device/lge/c660/prebuilt/mksh $(TARGET_RECOVERY_ROOT_OUT)/sbin/sh
	$(hide) chmod 755 $(TARGET_RECOVERY_ROOT_OUT)/sbin/sh
	@echo -e ${PRT_IMG}"----- Gingerbread adbd (this 2.6.35 kernel has legacy /dev/android_adb, no FunctionFS) ------"${CL_RST}
	$(hide) cp device/lge/c660/prebuilt/adbd $(TARGET_RECOVERY_ROOT_OUT)/sbin/adbd
	$(hide) chmod 755 $(TARGET_RECOVERY_ROOT_OUT)/sbin/adbd
	$(hide) sed -i 's|^service adbd /sbin/adbd .*|service adbd /sbin/adbd recovery|' $(TARGET_RECOVERY_ROOT_OUT)/init.rc
	$(hide) cat device/lge/c660/prebuilt/init.clearmisc.rc >> $(TARGET_RECOVERY_ROOT_OUT)/init.rc
	$(hide) mkdir -p $(TARGET_RECOVERY_ROOT_OUT)/system/bin
	$(hide) ln -sf /sbin/sh $(TARGET_RECOVERY_ROOT_OUT)/system/bin/sh
	@echo -e ${PRT_IMG}"----- Dropping bu, fat tools, pigz and libusbhost to fit the 5 MB partition ------"${CL_RST}
	$(hide) rm -f $(TARGET_RECOVERY_ROOT_OUT)/sbin/bu \
		$(TARGET_RECOVERY_ROOT_OUT)/sbin/fsck.fat \
		$(TARGET_RECOVERY_ROOT_OUT)/sbin/mkfs.fat \
		$(TARGET_RECOVERY_ROOT_OUT)/sbin/fatlabel \
		$(TARGET_RECOVERY_ROOT_OUT)/sbin/pigz \
		$(TARGET_RECOVERY_ROOT_OUT)/sbin/unpigz \
		$(TARGET_RECOVERY_ROOT_OUT)/sbin/libusbhost.so
	@echo -e ${PRT_IMG}"----- Title bar: right-align the clock and shorten the battery label so 'by <author>' fits ------"${CL_RST}
	$(hide) sed -i 's|<placement x="%center_x%" y="%row1_header_y%" placement="5"/>|<placement x="256" y="%row1_header_y%" placement="1"/>|' $(TARGET_RECOVERY_ROOT_OUT)$(TWRES_PATH)ui.xml
	$(hide) sed -i 's|>Battery: %tw_battery%<|>Bat: %tw_battery%<|' $(TARGET_RECOVERY_ROOT_OUT)$(TWRES_PATH)languages/en.xml
	$(hide) $(MKBOOTFS) $(TARGET_RECOVERY_ROOT_OUT) > $(recovery_uncompressed_ramdisk)
	@echo -e ${PRT_IMG}"----- Compressing recovery ramdisk with gzip ------"${CL_RST}
	$(MINIGZIP) < $(recovery_uncompressed_ramdisk) > $(recovery_ramdisk)
	@echo -e ${PRT_IMG}"----- Making recovery image ------"${CL_RST}
	$(MKBOOTIMG) $(INTERNAL_RECOVERYIMAGE_ARGS) --output $@
	$(hide) image_size=$$(wc -c < $@); \
		partition_size=$$(( $(BOARD_RECOVERYIMAGE_PARTITION_SIZE) )); \
		if [ $$image_size -gt $$partition_size ]; then \
			echo "error: $@ too large ($$image_size > $$partition_size)"; \
			exit 1; \
		fi
	@echo -e ${PRT_IMG}"----- Made recovery image: $@ --------"${CL_RST}
