SHELL := /bin/bash

# Rules
.PHONY: all
all:
	source setupsdk && bitbake core-image-minimal
	
.PHONY: clean
clean:
	rm -rf build/bitbake-cookerdaemon.log build/cache build/sstate-cache build/tmp-glibc

.PHONY: veryclean
veryclean: clean
	rm -rf build/xsct build/downloads
