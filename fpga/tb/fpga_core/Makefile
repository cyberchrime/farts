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

DUT      = fpga_core
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
VERILOG_SOURCES += ../../rtl/$(DUT).v
VERILOG_SOURCES += ../../rtl/dma_controller.v
VERILOG_SOURCES += ../../rtl/rgmii_pcap.v
VERILOG_SOURCES += ../../rtl/axil_dma_ctrl_regs.v
VERILOG_SOURCES += ../../rtl/axil_mac_ctrl_regs.v
VERILOG_SOURCES += ../../rtl/phy_bridge.v
VERILOG_SOURCES += ../../rtl/async_edge_detect.v
VERILOG_SOURCES += ../../rtl/axil_mdio_if.v
VERILOG_SOURCES += ../../rtl/axil_mdio_controller.v
VERILOG_SOURCES += ../../rtl/mdio_master.v
VERILOG_SOURCES += ../../rtl/axis_prepend.v
VERILOG_SOURCES += ../../rtl/pipeline.v
VERILOG_SOURCES += ../../rtl/pcap_clock.v
VERILOG_SOURCES += ../../rtl/gray_code_counter.v
VERILOG_SOURCES += ../../rtl/gray2bin.v
VERILOG_SOURCES += ../../rtl/rgmii_rx.v
VERILOG_SOURCES += ../../rtl/simple_fifo.v
VERILOG_SOURCES += ../../rtl/word_cdc.v
VERILOG_SOURCES += ../../rtl/dma_desc_regs.v
VERILOG_SOURCES += ../../rtl/axil_bram.v
VERILOG_SOURCES += ../../rtl/axi_dma_wr.v
VERILOG_SOURCES += ../../lib/verilog-axi/rtl/axil_adapter.v
VERILOG_SOURCES += ../../lib/verilog-axi/rtl/axil_adapter_rd.v
VERILOG_SOURCES += ../../lib/verilog-axi/rtl/axil_adapter_wr.v
VERILOG_SOURCES += ../../lib/verilog-ethernet/rtl/iddr.v
VERILOG_SOURCES += ../../lib/verilog-ethernet/rtl/ssio_ddr_in.v
VERILOG_SOURCES += ../../lib/verilog-ethernet/rtl/axis_gmii_rx.v
VERILOG_SOURCES += ../../lib/verilog-ethernet/rtl/lfsr.v
VERILOG_SOURCES += ../../lib/verilog-ethernet/rtl/rgmii_phy_if.v
VERILOG_SOURCES += ../../lib/verilog-axis/rtl/axis_fifo_adapter.v
VERILOG_SOURCES += ../../lib/verilog-axis/rtl/axis_adapter.v
VERILOG_SOURCES += ../../lib/verilog-axis/rtl/arbiter.v
VERILOG_SOURCES += ../../lib/verilog-axis/rtl/priority_encoder.v
VERILOG_SOURCES += ../../lib/verilog-axis/rtl/axis_arb_mux.v
VERILOG_SOURCES += ../../lib/verilog-axis/rtl/axis_fifo.v
VERILOG_SOURCES += ../../lib/verilog-axis/rtl/axis_async_fifo_adapter.v
VERILOG_SOURCES += ../../lib/verilog-axis/rtl/axis_async_fifo.v
VERILOG_SOURCES += ../../lib/verilog-axis/rtl/axis_frame_len.v

# module parameters
export PARAM_AXI_DATA_WIDTH ?= 64
export PARAM_AXI_ADDR_WIDTH ?= 32
export PARAM_AXI_ID_WIDTH ?= 8
export PARAM_AXI_MAX_BURST_LEN ?= 8
export PARAM_LEN_WIDTH ?= 12
export PARAM_AXIL_DMA_DATA_WIDTH ?= 32
export PARAM_AXIL_DMA_ADDR_WIDTH ?= 8
export PARAM_AXIL_DMA_DESC_DATA_WIDTH ?= 32
export PARAM_AXIL_DMA_DESC_ADDR_WIDTH ?= 12
export PARAM_AXIL_MDIO_DATA_WIDTH ?= 32
export PARAM_AXIL_MDIO_ADDR_WIDTH ?= 7

PLUSARGS += -fst

COMPILE_ARGS += -P $(TOPLEVEL).AXI_DATA_WIDTH=$(PARAM_AXI_DATA_WIDTH)
COMPILE_ARGS += -P $(TOPLEVEL).AXI_ADDR_WIDTH=$(PARAM_AXI_ADDR_WIDTH)
COMPILE_ARGS += -P $(TOPLEVEL).AXI_ID_WIDTH=$(PARAM_AXI_ID_WIDTH)
COMPILE_ARGS += -P $(TOPLEVEL).AXI_MAX_BURST_LEN=$(PARAM_AXI_MAX_BURST_LEN)
COMPILE_ARGS += -P $(TOPLEVEL).AXIL_DMA_DATA_WIDTH=$(PARAM_AXIL_DMA_DATA_WIDTH)
COMPILE_ARGS += -P $(TOPLEVEL).AXIL_DMA_ADDR_WIDTH=$(PARAM_AXIL_DMA_ADDR_WIDTH)
COMPILE_ARGS += -P $(TOPLEVEL).AXIL_DMA_DESC_DATA_WIDTH=$(PARAM_AXIL_DMA_DESC_DATA_WIDTH)
COMPILE_ARGS += -P $(TOPLEVEL).AXIL_DMA_DESC_ADDR_WIDTH=$(PARAM_AXIL_DMA_DESC_ADDR_WIDTH)
COMPILE_ARGS += -P $(TOPLEVEL).AXIL_MDIO_DATA_WIDTH=$(PARAM_AXIL_MDIO_DATA_WIDTH)
COMPILE_ARGS += -P $(TOPLEVEL).AXIL_MDIO_ADDR_WIDTH=$(PARAM_AXIL_MDIO_ADDR_WIDTH)

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
