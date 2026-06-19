ROOTDIR ?= /

.PHONY: install image iso check

install:
	ROOTDIR="$(ROOTDIR)" sh scripts/install-voidbsd.sh

image:
	sh scripts/build-raw-image.sh

iso:
	sh scripts/build-installer-iso.sh

check:
	sh -n scripts/install-voidbsd.sh
	sh -n scripts/install-zen.sh
	sh -n scripts/build-raw-image.sh
	sh -n scripts/build-installer-iso.sh
	sh -n scripts/configure-user.sh
	sh -n overlay/usr/local/libexec/voidbsd/first-login.sh
	sh -n overlay/usr/local/etc/rc.d/voidbsd_gpu_detect
