# Copyright (c) 2023 Chris H. Meyer
#
# This file is part of aRTS.
#
# aRTS is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# aRTS is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with aRTS. If not, see <https://www.gnu.org/licenses/>.


# Rules
.PHONY: all
all: sw

.PHONY: sw
sw: fpga
	make -C sw

.PHONY: fpga
fpga:
	make -C fpga

.PHONY: clean
clean:
	make clean -C fpga
	make clean -C sw

.PHONY: veryclean
veryclean: clean
	make veryclean -C sw
