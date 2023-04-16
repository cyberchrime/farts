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


set params [dict create]

# AXI interface configuration (DMA)
open_bd_design [get_files zynq_ps.bd]
set s_axi_dma [get_bd_intf_ports s_axi_dma]
dict set params AXI_DATA_WIDTH [get_property CONFIG.DATA_WIDTH $s_axi_dma]
dict set params AXI_DMA_MAX_BURST_LEN = 10
dict set params AXI_ID_WIDTH [get_property CONFIG.ID_WIDTH $s_axi_dma]
dict set params AXI_ADDR_WIDTH = 32

# AXI lite interface configuration (control)
set m_axil_dma [get_bd_intf_ports m_axil_dma]
dict set params AXIL_DMA_DATA_WIDTH [get_property CONFIG.DATA_WIDTH $m_axil_dma]
dict set params AXIL_DMA_ADDR_WIDTH 8

set m_axil_dma_desc [get_bd_intf_ports m_axil_dma_desc]
dict set params AXIL_DMA_DESC_DATA_WIDTH [get_property CONFIG.DATA_WIDTH $m_axil_dma_desc]
dict set params AXIL_DMA_DESC_ADDR_WIDTH 12

set m_axil_mac [get_bd_intf_ports m_axil_mac]
dict set params AXIL_MAC_DATA_WIDTH [get_property CONFIG.DATA_WIDTH $m_axil_mac]
dict set params AXIL_MAC_ADDR_WIDTH 8

set m_axil_mdio [get_bd_intf_ports m_axil_mdio]
dict set params AXIL_MDIO_DATA_WIDTH [get_property CONFIG.DATA_WIDTH $m_axil_mdio]
dict set params AXIL_MDIO_ADDR_WIDTH 8

set fclk_clk1 [get_bd_ports fclk_clk1]
set freq [get_property CONFIG.FREQ_HZ $fclk_clk1]
set period [expr 1000000000/$freq]
dict set params CLOCK_PERIOD $period

# apply parameters to top-level
set param_list {}
dict for {name value} $params {
    lappend param_list $name=$value
}

# set_property generic $param_list [current_fileset]
set_property generic $param_list [get_filesets sources_1]
