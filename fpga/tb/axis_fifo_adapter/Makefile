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


TOPLEVEL_LANG = verilog

SIM ?= icarus
WAVES ?= 0

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

DUT      = axis_frame_len_insert
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
VERILOG_SOURCES += ../../rtl/$(DUT).v
VERILOG_SOURCES += ../../rtl/axis_insert.v
VERILOG_SOURCES += ../../rtl/axis_prepend.v
VERILOG_SOURCES += ../../rtl/simple_fifo.v
VERILOG_SOURCES += ../../lib/verilog-axis/rtl/axis_fifo.v
VERILOG_SOURCES += ../../lib/verilog-axis/rtl/axis_frame_len.v

# module parameters
export PARAM_DATA_WIDTH ?= 8
export PARAM_USER_WIDTH ?= 1
export PARAM_PAYLOAD_OFFSET ?= 8
export PARAM_ENDIANESS ?= \"LITTLE\"

PLUSARGS += -fst

COMPILE_ARGS += -P $(TOPLEVEL).DATA_WIDTH=$(PARAM_DATA_WIDTH)
COMPILE_ARGS += -P $(TOPLEVEL).USER_WIDTH=$(PARAM_USER_WIDTH)
COMPILE_ARGS += -P $(TOPLEVEL).PAYLOAD_OFFSET=$(PARAM_PAYLOAD_OFFSET)
COMPILE_ARGS += -P $(TOPLEVEL).ENDIANESS=$(PARAM_ENDIANESS)

ifeq ($(WAVES), 1)
	VERILOG_SOURCES += iverilog_dump.v
	COMPILE_ARGS += -s iverilog_dump
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

iverilog_dump.v:
	echo 'module iverilog_dump();' > $@
	echo 'initial begin' >> $@
	echo '    $$dumpfile("$(TOPLEVEL).fst");' >> $@
	echo '    $$dumpvars(0, $(TOPLEVEL));' >> $@
	echo 'end' >> $@
	echo 'endmodule' >> $@

clean::
	@rm -rf iverilog_dump.v
	@rm -rf dump.fst $(TOPLEVEL).fst
	@rm -rf results.xml
	@rm -rf __pycache__
