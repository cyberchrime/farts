unset KBUILD_DEFCONFIG

FILESEXTRAPATHS:prepend := "${THISDIR}:"

SRC_URI += "file://sniffer_defconfig"
