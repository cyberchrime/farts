DESCRIPTION = "User Space tool printing a PCAP global header to stdout"
LICENSE = "GPL"

LIC_FILES_CHKSUM = " \
                file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6 \
                "


SRC_URI = "file://header.c"

S = "${WORKDIR}"

do_compile() {
	${CC} header.c ${LDFLAGS} -o header
}

do_install() {
	install -d ${D}${bindir}
	install -m 0755 header ${D}${bindir}
}
