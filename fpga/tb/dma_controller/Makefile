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

DUT      = dma_controller
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
VERILOG_SOURCES = ../../rtl/$(DUT).v
VERILOG_SOURCES += ../../rtl/axil_dma_ctrl_regs.v
VERILOG_SOURCES += ../../rtl/axil_bram.v
VERILOG_SOURCES += ../../rtl/dma_desc_regs.v
VERILOG_SOURCES += ../../rtl/axi_dma_wr.v
VERILOG_SOURCES += ../../lib/verilog-axi/rtl/axil_adapter.v
VERILOG_SOURCES += ../../lib/verilog-axi/rtl/axil_adapter_rd.v
VERILOG_SOURCES += ../../lib/verilog-axi/rtl/axil_adapter_wr.v

# module parameters
export PARAM_AXIL_DATA_WIDTH ?= 32
export PARAM_AXIL_ADDR_WIDTH ?= 8
export PARAM_AXIL_DESC_DATA_WIDTH ?= 32
export PARAM_AXIL_DESC_ADDR_WIDTH ?= 12
export PARAM_AXI_DATA_WIDTH ?= 64
export PARAM_AXI_MAX_BURST_LEN ?= 4
export PARAM_AXI_ADDR_WIDTH ?= 32
export PARAM_AXI_ID_WIDTH ?= 8
export PARAM_AXIS_LAST_ENABLE ?= 1
export PARAM_AXIS_USER_ENABLE ?= 1
export PARAM_AXIS_USER_WIDTH ?= 1
export PARAM_TAG_WIDTH ?= 8
export PARAM_LEN_WIDTH ?= 12

PLUSARGS += -fst

COMPILE_ARGS += -P $(TOPLEVEL).AXIL_DATA_WIDTH=$(PARAM_AXIL_DATA_WIDTH)
COMPILE_ARGS += -P $(TOPLEVEL).AXIL_ADDR_WIDTH=$(PARAM_AXIL_ADDR_WIDTH)
COMPILE_ARGS += -P $(TOPLEVEL).AXIL_DESC_DATA_WIDTH=$(PARAM_AXIL_DESC_DATA_WIDTH)
COMPILE_ARGS += -P $(TOPLEVEL).AXIL_DESC_ADDR_WIDTH=$(PARAM_AXIL_DESC_ADDR_WIDTH)
COMPILE_ARGS += -P $(TOPLEVEL).AXI_DATA_WIDTH=$(PARAM_AXI_DATA_WIDTH)
COMPILE_ARGS += -P $(TOPLEVEL).AXI_MAX_BURST_LEN=$(PARAM_AXI_MAX_BURST_LEN)
COMPILE_ARGS += -P $(TOPLEVEL).AXI_ADDR_WIDTH=$(PARAM_AXI_ADDR_WIDTH)
COMPILE_ARGS += -P $(TOPLEVEL).AXI_ID_WIDTH=$(PARAM_AXI_ID_WIDTH)
COMPILE_ARGS += -P $(TOPLEVEL).AXIS_LAST_ENABLE=$(PARAM_AXIS_LAST_ENABLE)
COMPILE_ARGS += -P $(TOPLEVEL).AXIS_USER_ENABLE=$(PARAM_AXIS_USER_ENABLE)
COMPILE_ARGS += -P $(TOPLEVEL).AXIS_USER_WIDTH=$(PARAM_AXIS_USER_WIDTH)
COMPILE_ARGS += -P $(TOPLEVEL).TAG_WIDTH=$(PARAM_TAG_WIDTH)
COMPILE_ARGS += -P $(TOPLEVEL).LEN_WIDTH=$(PARAM_LEN_WIDTH)

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
