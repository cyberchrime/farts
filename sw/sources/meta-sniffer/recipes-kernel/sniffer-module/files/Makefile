# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2023 Chris H. Meyer

obj-m := sniffer.o
sniffer-y := sniffer_main.o sniffer_mdio.o sniffer_phylink.o sniffer_file_io.o sniffer_sysfs.o
#ccflags-y := -DDEBUG

SRC := $(shell pwd)

.PHONY: all modules_install clean

all:
	$(MAKE) -C $(KERNEL_SRC) M=$(SRC)

modules_install:
	$(MAKE) -C $(KERNEL_SRC) M=$(SRC) modules_install

clean:
	rm -f *.mod *.mod.c *.o *.ko Module.symvers modules.order
