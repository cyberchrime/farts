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


# FPGA settings
FPGA_PART = xc7z020clg484-1
FPGA_TOP = fpga
FPGA_ARCH = zynq

# Files for synthesis
SYN_FILES = rtl/fpga.v
SYN_FILES += rtl/fpga_core.v
SYN_FILES += rtl/async_edge_detect.v
SYN_FILES += rtl/axil_dma_ctrl_regs.v
SYN_FILES += rtl/dma_controller.v
SYN_FILES += rtl/axil_mdio_controller.v
SYN_FILES += rtl/axil_mdio_if.v
SYN_FILES += rtl/mdio_master.v
SYN_FILES += rtl/axil_mac_ctrl_regs.v
SYN_FILES += rtl/phy_bridge.v
SYN_FILES += rtl/fpga_core.v
SYN_FILES += rtl/rgmii_pcap.v
SYN_FILES += rtl/axis_prepend.v
SYN_FILES += rtl/pcap_clock.v
SYN_FILES += rtl/rgmii_rx.v
SYN_FILES += rtl/rgmii_pcap.v
SYN_FILES += rtl/word_cdc.v
SYN_FILES += rtl/pipeline.v
SYN_FILES += rtl/axil_bram.v
SYN_FILES += rtl/dma_desc_regs.v
SYN_FILES += rtl/axi_dma_wr.v
SYN_FILES += lib/verilog-axi/rtl/axil_adapter.v
SYN_FILES += lib/verilog-axi/rtl/axil_adapter_rd.v
SYN_FILES += lib/verilog-axi/rtl/axil_adapter_wr.v
SYN_FILES += lib/verilog-axis/rtl/arbiter.v
SYN_FILES += lib/verilog-axis/rtl/priority_encoder.v
SYN_FILES += lib/verilog-axis/rtl/axis_arb_mux.v
SYN_FILES += lib/verilog-axis/rtl/axis_fifo.v
SYN_FILES += lib/verilog-axis/rtl/axis_adapter.v
SYN_FILES += lib/verilog-axis/rtl/axis_async_fifo.v
SYN_FILES += lib/verilog-axis/rtl/axis_async_fifo_adapter.v
SYN_FILES += lib/verilog-axis/rtl/axis_frame_len.v
SYN_FILES += lib/verilog-ethernet/rtl/iddr.v
SYN_FILES += lib/verilog-ethernet/rtl/ssio_ddr_in.v
SYN_FILES += lib/verilog-ethernet/rtl/axis_gmii_rx.v
SYN_FILES += lib/verilog-ethernet/rtl/lfsr.v

# XDC files
XDC_FILES = fpga.xdc
XDC_FILES += lib/verilog-axis/syn/vivado/axis_async_fifo.tcl
XDC_FILES += syn/word_cdc.tcl

# IP
IP_TCL_FILES = ip/zynq_ps.tcl

# Configuration
CONFIG_TCL_FILES = ./config.tcl

include ../common/vivado.mk

program: $(FPGA_TOP).bit
	echo "open_hw" > program.tcl
	echo "connect_hw_server" >> program.tcl
	echo "open_hw_target" >> program.tcl
	echo "current_hw_device [lindex [get_hw_devices] 0]" >> program.tcl
	echo "refresh_hw_device -update_hw_probes false [current_hw_device]" >> program.tcl
	echo "set_property PROGRAM.FILE {$(FPGA_TOP).bit} [current_hw_device]" >> program.tcl
	echo "program_hw_devices [current_hw_device]" >> program.tcl
	echo "exit" >> program.tcl
	vivado -nojournal -nolog -mode batch -source program.tcl
