# SPDX-License-Identifier: BSD-2-Clause
# idregs-arm64: static arm64 binary, nolibc (tools/include/nolibc of a
# Linux tree, NOLIBC=) and the kernel UAPI headers (UAPI=).
CROSS_COMPILE ?= aarch64-linux-gnu-
NOLIBC ?= /opt/nolibc
UAPI ?= /opt/uapi
CFLAGS = -Os -march=armv8.3-a -static -nostdlib -fno-asynchronous-unwind-tables -fno-ident \
	-fno-stack-protector -Wall -Wextra -Wno-unused-parameter \
	-I$(NOLIBC) -isystem $(UAPI) -include nolibc.h -Wl,--build-id=none -Wl,-z,max-page-size=4096 -Wl,--gc-sections -ffunction-sections -fdata-sections -s

idregs-arm64: idregs.c
	$(CROSS_COMPILE)gcc $(CFLAGS) -o $@ $<

clean:
	rm -f idregs-arm64
