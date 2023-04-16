SUMMARY = "Example of how to build an external Linux kernel module"
DESCRIPTION = "${SUMMARY}"
LICENSE = "GPLv2+"
LIC_FILES_CHKSUM = "file://LICENSE;md5=02e02f23e1bff3713624d03c6fa2081d"

inherit module

SRC_URI = "file://Makefile \
           file://LICENSE \
           file://sniffer_file_io.c \
           file://sniffer.h \
           file://sniffer_main.c \
           file://sniffer_mdio.c \
           file://sniffer_phylink.c \
           file://sniffer_sysfs.c \
           "

S = "${WORKDIR}"

DEPENDS += "virtual/kernel"

RPROVIDES:${PN} += "kernel-module-sniffer"
