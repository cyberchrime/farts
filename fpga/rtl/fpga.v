/*

Copyright (c) 2023 Chris H. Meyer

This file is part of aRTS.

aRTS is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

aRTS is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License along
with aRTS. If not, see <https://www.gnu.org/licenses/>.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * FPGA top-level module
 */
module fpga #
(
    // Clock period
    parameter CLOCK_PERIOD = 5,

    // AXI lite interface configuration (control)
    parameter AXIL_DMA_DATA_WIDTH = 32,
    parameter AXIL_DMA_ADDR_WIDTH = 4,
    parameter AXIL_DMA_STRB_WIDTH = (AXIL_DMA_DATA_WIDTH/8),

    parameter AXIL_DMA_DESC_DATA_WIDTH = 32,
    parameter AXIL_DMA_DESC_ADDR_WIDTH = 12,
    parameter AXIL_DMA_DESC_STRB_WIDTH = (AXIL_DMA_DESC_DATA_WIDTH/8),

    parameter AXIL_MAC_DATA_WIDTH = 32,
    parameter AXIL_MAC_ADDR_WIDTH = 8,
    parameter AXIL_MAC_STRB_WIDTH = (AXIL_MAC_DATA_WIDTH/8),

    parameter AXIL_MDIO_DATA_WIDTH = 32,
    parameter AXIL_MDIO_ADDR_WIDTH = 8,
    parameter AXIL_MDIO_STRB_WIDTH = (AXIL_MDIO_DATA_WIDTH/8),

    // AXI interface configuration (DMA)
    parameter AXI_DMA_MAX_BURST_LEN = 8,
    parameter AXI_ID_WIDTH = 8,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 64,
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8)
)
(
    /*
     * PL LEDs
     */
    output wire [7:0] led,

    /*
     * Ethernet PORT 1: 1000BASE-T RGMII
     */
    input  wire        phy1_rgmii_rx_clk,
    input  wire [3:0]  phy1_rgmii_rxd,
    input  wire        phy1_rgmii_rx_ctl,
    output wire        phy1_rgmii_tx_clk,
    output wire [3:0]  phy1_rgmii_txd,
    output wire        phy1_rgmii_tx_ctl,
    output wire        phy1_reset_n,
    input  wire        phy1_int_n,
    input  wire        phy1_pme_n,

    output wire        phy1_mdc,
    inout  wire        phy1_mdio,

    /*
     * Ethernet PORT 2: 1000BASE-T RGMII
     */
    input  wire        phy2_rgmii_rx_clk,
    input  wire [3:0]  phy2_rgmii_rxd,
    input  wire        phy2_rgmii_rx_ctl,
    output wire        phy2_rgmii_tx_clk,
    output wire [3:0]  phy2_rgmii_txd,
    output wire        phy2_rgmii_tx_ctl,
    output wire        phy2_reset_n,
    input  wire        phy2_int_n,
    input  wire        phy2_pme_n,

    output wire        phy2_mdc,
    inout  wire        phy2_mdio
);


// Clock and reset
wire zynq_pl_clk0;
wire zynq_pl_clk1;
wire zynq_pl_clk2;
wire zynq_pl_reset;

// Interrupts
wire dma_irq;

// AXI lite DMA connections
wire [AXIL_DMA_ADDR_WIDTH-1:0] axil_dma_awaddr;
wire [2:0]                     axil_dma_awprot;
wire                           axil_dma_awvalid;
wire                           axil_dma_awready;
wire [AXIL_DMA_DATA_WIDTH-1:0] axil_dma_wdata;
wire [AXIL_DMA_STRB_WIDTH-1:0] axil_dma_wstrb;
wire                           axil_dma_wvalid;
wire                           axil_dma_wready;
wire [1:0]                     axil_dma_bresp;
wire                           axil_dma_bvalid;
wire                           axil_dma_bready;
wire [AXIL_DMA_ADDR_WIDTH-1:0] axil_dma_araddr;
wire [2:0]                     axil_dma_arprot;
wire                           axil_dma_arvalid;
wire                           axil_dma_arready;
wire [AXIL_DMA_DATA_WIDTH-1:0] axil_dma_rdata;
wire [1:0]                     axil_dma_rresp;
wire                           axil_dma_rvalid;
wire                           axil_dma_rready;

// AXI lite DMA descriptor connections
wire [AXIL_DMA_DESC_ADDR_WIDTH-1:0] axil_dma_desc_awaddr;
wire [2:0]                          axil_dma_desc_awprot;
wire                                axil_dma_desc_awvalid;
wire                                axil_dma_desc_awready;
wire [AXIL_DMA_DESC_DATA_WIDTH-1:0] axil_dma_desc_wdata;
wire [AXIL_DMA_DESC_STRB_WIDTH-1:0] axil_dma_desc_wstrb;
wire                                axil_dma_desc_wvalid;
wire                                axil_dma_desc_wready;
wire [1:0]                          axil_dma_desc_bresp;
wire                                axil_dma_desc_bvalid;
wire                                axil_dma_desc_bready;
wire [AXIL_DMA_DESC_ADDR_WIDTH-1:0] axil_dma_desc_araddr;
wire [2:0]                          axil_dma_desc_arprot;
wire                                axil_dma_desc_arvalid;
wire                                axil_dma_desc_arready;
wire [AXIL_DMA_DESC_DATA_WIDTH-1:0] axil_dma_desc_rdata;
wire [1:0]                          axil_dma_desc_rresp;
wire                                axil_dma_desc_rvalid;
wire                                axil_dma_desc_rready;

// AXI lite MAC connections
wire [AXIL_MAC_ADDR_WIDTH-1:0] axil_mac_awaddr;
wire [2:0]                     axil_mac_awprot;
wire                           axil_mac_awvalid;
wire                           axil_mac_awready;
wire [AXIL_MAC_DATA_WIDTH-1:0] axil_mac_wdata;
wire [AXIL_MAC_STRB_WIDTH-1:0] axil_mac_wstrb;
wire                           axil_mac_wvalid;
wire                           axil_mac_wready;
wire [1:0]                     axil_mac_bresp;
wire                           axil_mac_bvalid;
wire                           axil_mac_bready;
wire [AXIL_MAC_ADDR_WIDTH-1:0] axil_mac_araddr;
wire [2:0]                     axil_mac_arprot;
wire                           axil_mac_arvalid;
wire                           axil_mac_arready;
wire [AXIL_MAC_DATA_WIDTH-1:0] axil_mac_rdata;
wire [1:0]                     axil_mac_rresp;
wire                           axil_mac_rvalid;
wire                           axil_mac_rready;

// AXI lite MDIO interfaces
wire [AXIL_MDIO_ADDR_WIDTH-1:0] axil_mdio_awaddr;
wire [2:0]                      axil_mdio_awprot;
wire                            axil_mdio_awvalid;
wire                            axil_mdio_awready;
wire [AXIL_MDIO_DATA_WIDTH-1:0] axil_mdio_wdata;
wire [AXIL_MDIO_STRB_WIDTH-1:0] axil_mdio_wstrb;
wire                            axil_mdio_wvalid;
wire                            axil_mdio_wready;
wire [1:0]                      axil_mdio_bresp;
wire                            axil_mdio_bvalid;
wire                            axil_mdio_bready;
wire [AXIL_MDIO_ADDR_WIDTH-1:0] axil_mdio_araddr;
wire [2:0]                      axil_mdio_arprot;
wire                            axil_mdio_arvalid;
wire                            axil_mdio_arready;
wire [AXIL_MDIO_DATA_WIDTH-1:0] axil_mdio_rdata;
wire [1:0]                      axil_mdio_rresp;
wire                            axil_mdio_rvalid;
wire                            axil_mdio_rready;

// Zynq AXI DMA interface
wire [AXI_ID_WIDTH-1:0]   axi_awid;
wire [AXI_ADDR_WIDTH-1:0] axi_awaddr;
wire [7:0]                axi_awlen;
wire [2:0]                axi_awsize;
wire [1:0]                axi_awburst;
wire                      axi_awlock;
wire [3:0]                axi_awcache;
wire [2:0]                axi_awprot;
wire                      axi_awvalid;
wire                      axi_awready;
wire [AXI_DATA_WIDTH-1:0] axi_wdata;
wire [AXI_STRB_WIDTH-1:0] axi_wstrb;
wire                      axi_wlast;
wire                      axi_wvalid;
wire                      axi_wready;
wire [AXI_ID_WIDTH-1:0]   axi_bid;
wire [1:0]                axi_bresp;
wire                      axi_bvalid;
wire                      axi_bready;
wire [AXI_ID_WIDTH-1:0]   axi_arid;
wire [AXI_ADDR_WIDTH-1:0] axi_araddr;
wire [7:0]                axi_arlen;
wire [2:0]                axi_arsize;
wire [1:0]                axi_arburst;
wire                      axi_arlock;
wire [3:0]                axi_arcache;
wire [2:0]                axi_arprot;
wire                      axi_arvalid;
wire                      axi_arready;
wire [AXI_ID_WIDTH-1:0]   axi_rid;
wire [AXI_DATA_WIDTH-1:0] axi_rdata;
wire [1:0]                axi_rresp;
wire                      axi_rlast;
wire                      axi_rvalid;
wire                      axi_rready;

zynq_ps zynq_ps_inst (
    .fclk_clk0(axi_clk),
    .fclk_clk1(counter_clk),
    .fclk_reset0(axi_rst),
    .fclk_reset1(counter_rst),

    .dma_irq(dma_irq),

    .m_axil_mdio_araddr(axil_mdio_araddr),
    .m_axil_mdio_arprot(axil_mdio_arprot),
    .m_axil_mdio_arready(axil_mdio_arready),
    .m_axil_mdio_arvalid(axil_mdio_arvalid),
    .m_axil_mdio_awaddr(axil_mdio_awaddr),
    .m_axil_mdio_awprot(axil_mdio_awprot),
    .m_axil_mdio_awready(axil_mdio_awready),
    .m_axil_mdio_awvalid(axil_mdio_awvalid),
    .m_axil_mdio_bready(axil_mdio_bready),
    .m_axil_mdio_bresp(axil_mdio_bresp),
    .m_axil_mdio_bvalid(axil_mdio_bvalid),
    .m_axil_mdio_rdata(axil_mdio_rdata),
    .m_axil_mdio_rready(axil_mdio_rready),
    .m_axil_mdio_rresp(axil_mdio_rresp),
    .m_axil_mdio_rvalid(axil_mdio_rvalid),
    .m_axil_mdio_wdata(axil_mdio_wdata),
    .m_axil_mdio_wready(axil_mdio_wready),
    .m_axil_mdio_wstrb(axil_mdio_wstrb),
    .m_axil_mdio_wvalid(axil_mdio_wvalid),

    .m_axil_dma_araddr(axil_dma_araddr),
    .m_axil_dma_arprot(axil_dma_arprot),
    .m_axil_dma_arready(axil_dma_arready),
    .m_axil_dma_arvalid(axil_dma_arvalid),
    .m_axil_dma_awaddr(axil_dma_awaddr),
    .m_axil_dma_awprot(axil_dma_awprot),
    .m_axil_dma_awready(axil_dma_awready),
    .m_axil_dma_awvalid(axil_dma_awvalid),
    .m_axil_dma_bready(axil_dma_bready),
    .m_axil_dma_bresp(axil_dma_bresp),
    .m_axil_dma_bvalid(axil_dma_bvalid),
    .m_axil_dma_rdata(axil_dma_rdata),
    .m_axil_dma_rready(axil_dma_rready),
    .m_axil_dma_rresp(axil_dma_rresp),
    .m_axil_dma_rvalid(axil_dma_rvalid),
    .m_axil_dma_wdata(axil_dma_wdata),
    .m_axil_dma_wready(axil_dma_wready),
    .m_axil_dma_wstrb(axil_dma_wstrb),
    .m_axil_dma_wvalid(axil_dma_wvalid),

    .m_axil_dma_desc_araddr(axil_dma_desc_araddr),
    .m_axil_dma_desc_arprot(axil_dma_desc_arprot),
    .m_axil_dma_desc_arready(axil_dma_desc_arready),
    .m_axil_dma_desc_arvalid(axil_dma_desc_arvalid),
    .m_axil_dma_desc_awaddr(axil_dma_desc_awaddr),
    .m_axil_dma_desc_awprot(axil_dma_desc_awprot),
    .m_axil_dma_desc_awready(axil_dma_desc_awready),
    .m_axil_dma_desc_awvalid(axil_dma_desc_awvalid),
    .m_axil_dma_desc_bready(axil_dma_desc_bready),
    .m_axil_dma_desc_bresp(axil_dma_desc_bresp),
    .m_axil_dma_desc_bvalid(axil_dma_desc_bvalid),
    .m_axil_dma_desc_rdata(axil_dma_desc_rdata),
    .m_axil_dma_desc_rready(axil_dma_desc_rready),
    .m_axil_dma_desc_rresp(axil_dma_desc_rresp),
    .m_axil_dma_desc_rvalid(axil_dma_desc_rvalid),
    .m_axil_dma_desc_wdata(axil_dma_desc_wdata),
    .m_axil_dma_desc_wready(axil_dma_desc_wready),
    .m_axil_dma_desc_wstrb(axil_dma_desc_wstrb),
    .m_axil_dma_desc_wvalid(axil_dma_desc_wvalid),

    .m_axil_mac_araddr(axil_mac_araddr),
    .m_axil_mac_arprot(axil_mac_arprot),
    .m_axil_mac_arready(axil_mac_arready),
    .m_axil_mac_arvalid(axil_mac_arvalid),
    .m_axil_mac_awaddr(axil_mac_awaddr),
    .m_axil_mac_awprot(axil_mac_awprot),
    .m_axil_mac_awready(axil_mac_awready),
    .m_axil_mac_awvalid(axil_mac_awvalid),
    .m_axil_mac_bready(axil_mac_bready),
    .m_axil_mac_bresp(axil_mac_bresp),
    .m_axil_mac_bvalid(axil_mac_bvalid),
    .m_axil_mac_rdata(axil_mac_rdata),
    .m_axil_mac_rready(axil_mac_rready),
    .m_axil_mac_rresp(axil_mac_rresp),
    .m_axil_mac_rvalid(axil_mac_rvalid),
    .m_axil_mac_wdata(axil_mac_wdata),
    .m_axil_mac_wready(axil_mac_wready),
    .m_axil_mac_wstrb(axil_mac_wstrb),
    .m_axil_mac_wvalid(axil_mac_wvalid),

    .s_axi_dma_araddr(axi_araddr),
    .s_axi_dma_arburst(axi_arburst),
    .s_axi_dma_arcache(axi_arcache),
    .s_axi_dma_arid(axi_arid),
    .s_axi_dma_arlen(axi_arlen),
    .s_axi_dma_arlock(axi_arlock),
    .s_axi_dma_arprot({3'b0}),
    .s_axi_dma_arqos({4{1'b0}}),
    .s_axi_dma_arready(axi_arready),
    .s_axi_dma_arsize(axi_arsize),
    .s_axi_dma_arvalid(axi_arvalid),
    .s_axi_dma_awaddr(axi_awaddr),
    .s_axi_dma_awburst(axi_awburst),
    .s_axi_dma_awcache(axi_awcache),
    .s_axi_dma_awid(axi_awid),
    .s_axi_dma_awlen(axi_awlen),
    .s_axi_dma_awlock(axi_awlock),
    .s_axi_dma_awprot(3'b000),
    .s_axi_dma_awqos({4{1'b0}}),
    .s_axi_dma_awready(axi_awready),
    .s_axi_dma_awsize(axi_awsize),
    .s_axi_dma_awvalid(axi_awvalid),
    .s_axi_dma_bid(axi_bid),
    .s_axi_dma_bready(axi_bready),
    .s_axi_dma_bresp(axi_bresp),
    .s_axi_dma_bvalid(axi_bvalid),
    .s_axi_dma_rdata(axi_rdata),
    .s_axi_dma_rid(axi_rid),
    .s_axi_dma_rlast(axi_rlast),
    .s_axi_dma_rready(axi_rready),
    .s_axi_dma_rresp(axi_rresp),
    .s_axi_dma_rvalid(axi_rvalid),
    .s_axi_dma_wdata(axi_wdata),
    .s_axi_dma_wlast(axi_wlast),
    .s_axi_dma_wready(axi_wready),
    .s_axi_dma_wstrb(axi_wstrb),
    .s_axi_dma_wvalid(axi_wvalid)
);

wire axi_clk;
wire counter_clk;

wire axi_rst;
wire rst_n = ~axi_rst;
wire counter_rst;


assign phy1_reset_n = rst_n;
assign phy2_reset_n = rst_n;

fpga_core # (
    .TARGET("XILINX"),
    .IODDR_STYLE("IODDR"),
    .CLOCK_INPUT_STYLE("BUFR"),
    .USE_CLK90("TRUE"),
    .CLOCK_PERIOD(CLOCK_PERIOD),
    .AXIL_DMA_DATA_WIDTH(AXIL_DMA_DATA_WIDTH),
    .AXIL_DMA_ADDR_WIDTH(AXIL_DMA_ADDR_WIDTH),
    .AXIL_DMA_DESC_DATA_WIDTH(AXIL_DMA_DESC_DATA_WIDTH),
    .AXIL_DMA_DESC_ADDR_WIDTH(AXIL_DMA_DESC_ADDR_WIDTH),
    .AXIL_MDIO_DATA_WIDTH(AXIL_MDIO_DATA_WIDTH),
    .AXIL_MDIO_ADDR_WIDTH(AXIL_MDIO_ADDR_WIDTH),

    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_DMA_MAX_BURST_LEN)
)
fpga_core_inst (
    .axi_clk(axi_clk),
    .axi_rst(axi_rst),

    .counter_clk(counter_clk),
    .counter_rst(counter_rst),

    .m_axi_awid(axi_awid),
    .m_axi_awaddr(axi_awaddr),
    .m_axi_awlen(axi_awlen),
    .m_axi_awsize(axi_awsize),
    .m_axi_awburst(axi_awburst),
    .m_axi_awlock(axi_awlock),
    .m_axi_awcache(axi_awcache),
    .m_axi_awprot(axi_awprot),
    .m_axi_awvalid(axi_awvalid),
    .m_axi_awready(axi_awready),
    .m_axi_wdata(axi_wdata),
    .m_axi_wstrb(axi_wstrb),
    .m_axi_wlast(axi_wlast),
    .m_axi_wvalid(axi_wvalid),
    .m_axi_wready(axi_wready),
    .m_axi_bid(axi_bid),
    .m_axi_bresp(axi_bresp),
    .m_axi_bvalid(axi_bvalid),
    .m_axi_bready(axi_bready),
    .m_axi_arid(axi_arid),
    .m_axi_araddr(axi_araddr),
    .m_axi_arlen(axi_arlen),
    .m_axi_arsize(axi_arsize),
    .m_axi_arburst(axi_arburst),
    .m_axi_arlock(axi_arlock),
    .m_axi_arcache(axi_arcache),
    .m_axi_arprot(axi_arprot),
    .m_axi_arvalid(axi_arvalid),
    .m_axi_arready(axi_arready),
    .m_axi_rid(axi_rid),
    .m_axi_rdata(axi_rdata),
    .m_axi_rresp(axi_rresp),
    .m_axi_rlast(axi_rlast),
    .m_axi_rvalid(axi_rvalid),
    .m_axi_rready(axi_rready),
    .dma_irq(dma_irq),

    .s_axil_mac_awaddr(axil_mac_awaddr),
    .s_axil_mac_awprot(axil_mac_awprot),
    .s_axil_mac_awvalid(axil_mac_awvalid),
    .s_axil_mac_awready(axil_mac_awready),
    .s_axil_mac_wdata(axil_mac_wdata),
    .s_axil_mac_wstrb(axil_mac_wstrb),
    .s_axil_mac_wvalid(axil_mac_wvalid),
    .s_axil_mac_wready(axil_mac_wready),
    .s_axil_mac_bresp(axil_mac_bresp),
    .s_axil_mac_bvalid(axil_mac_bvalid),
    .s_axil_mac_bready(axil_mac_bready),
    .s_axil_mac_araddr(axil_mac_araddr),
    .s_axil_mac_arprot(axil_mac_arprot),
    .s_axil_mac_arvalid(axil_mac_arvalid),
    .s_axil_mac_arready(axil_mac_arready),
    .s_axil_mac_rdata(axil_mac_rdata),
    .s_axil_mac_rresp(axil_mac_rresp),
    .s_axil_mac_rvalid(axil_mac_rvalid),
    .s_axil_mac_rready(axil_mac_rready),

    .s_axil_dma_awaddr(axil_dma_awaddr),
    .s_axil_dma_awprot(axil_dma_awprot),
    .s_axil_dma_awvalid(axil_dma_awvalid),
    .s_axil_dma_awready(axil_dma_awready),
    .s_axil_dma_wdata(axil_dma_wdata),
    .s_axil_dma_wstrb(axil_dma_wstrb),
    .s_axil_dma_wvalid(axil_dma_wvalid),
    .s_axil_dma_wready(axil_dma_wready),
    .s_axil_dma_bresp(axil_dma_bresp),
    .s_axil_dma_bvalid(axil_dma_bvalid),
    .s_axil_dma_bready(axil_dma_bready),
    .s_axil_dma_araddr(axil_dma_araddr),
    .s_axil_dma_arprot(axil_dma_arprot),
    .s_axil_dma_arvalid(axil_dma_arvalid),
    .s_axil_dma_arready(axil_dma_arready),
    .s_axil_dma_rdata(axil_dma_rdata),
    .s_axil_dma_rresp(axil_dma_rresp),
    .s_axil_dma_rvalid(axil_dma_rvalid),
    .s_axil_dma_rready(axil_dma_rready),

    .s_axil_dma_desc_awaddr(axil_dma_desc_awaddr),
    .s_axil_dma_desc_awprot(axil_dma_desc_awprot),
    .s_axil_dma_desc_awvalid(axil_dma_desc_awvalid),
    .s_axil_dma_desc_awready(axil_dma_desc_awready),
    .s_axil_dma_desc_wdata(axil_dma_desc_wdata),
    .s_axil_dma_desc_wstrb(axil_dma_desc_wstrb),
    .s_axil_dma_desc_wvalid(axil_dma_desc_wvalid),
    .s_axil_dma_desc_wready(axil_dma_desc_wready),
    .s_axil_dma_desc_bresp(axil_dma_desc_bresp),
    .s_axil_dma_desc_bvalid(axil_dma_desc_bvalid),
    .s_axil_dma_desc_bready(axil_dma_desc_bready),
    .s_axil_dma_desc_araddr(axil_dma_desc_araddr),
    .s_axil_dma_desc_arprot(axil_dma_desc_arprot),
    .s_axil_dma_desc_arvalid(axil_dma_desc_arvalid),
    .s_axil_dma_desc_arready(axil_dma_desc_arready),
    .s_axil_dma_desc_rdata(axil_dma_desc_rdata),
    .s_axil_dma_desc_rresp(axil_dma_desc_rresp),
    .s_axil_dma_desc_rvalid(axil_dma_desc_rvalid),
    .s_axil_dma_desc_rready(axil_dma_desc_rready),

    .s_axil_mdio_araddr(axil_mdio_araddr),
    .s_axil_mdio_arprot(axil_mdio_arprot),
    .s_axil_mdio_arready(axil_mdio_arready),
    .s_axil_mdio_arvalid(axil_mdio_arvalid),
    .s_axil_mdio_awaddr(axil_mdio_awaddr),
    .s_axil_mdio_awprot(axil_mdio_awprot),
    .s_axil_mdio_awready(axil_mdio_awready),
    .s_axil_mdio_awvalid(axil_mdio_awvalid),
    .s_axil_mdio_bready(axil_mdio_bready),
    .s_axil_mdio_bresp(axil_mdio_bresp),
    .s_axil_mdio_bvalid(axil_mdio_bvalid),
    .s_axil_mdio_rdata(axil_mdio_rdata),
    .s_axil_mdio_rready(axil_mdio_rready),
    .s_axil_mdio_rresp(axil_mdio_rresp),
    .s_axil_mdio_rvalid(axil_mdio_rvalid),
    .s_axil_mdio_wdata(axil_mdio_wdata),
    .s_axil_mdio_wready(axil_mdio_wready),
    .s_axil_mdio_wstrb(axil_mdio_wstrb),
    .s_axil_mdio_wvalid(axil_mdio_wvalid),

    .phy1_rgmii_rx_clk(phy1_rgmii_rx_clk),
    .phy1_rgmii_rxd(phy1_rgmii_rxd),
    .phy1_rgmii_rx_ctl(phy1_rgmii_rx_ctl),
    .phy1_rgmii_tx_clk(phy1_rgmii_tx_clk),
    .phy1_rgmii_txd(phy1_rgmii_txd),
    .phy1_rgmii_tx_ctl(phy1_rgmii_tx_ctl),
    .phy1_reset_n(),
    .phy1_int_n(phy1_int_n),
    .phy1_pme_n(phy1_pme_n),

    .phy1_mdc(phy1_mdc),
    .phy1_mdio(phy1_mdio),

    .phy2_rgmii_rx_clk(phy2_rgmii_rx_clk),
    .phy2_rgmii_rxd(phy2_rgmii_rxd),
    .phy2_rgmii_rx_ctl(phy2_rgmii_rx_ctl),
    .phy2_rgmii_tx_clk(phy2_rgmii_tx_clk),
    .phy2_rgmii_txd(phy2_rgmii_txd),
    .phy2_rgmii_tx_ctl(phy2_rgmii_tx_ctl),
    .phy2_reset_n(),
    .phy2_int_n(phy2_int_n),
    .phy2_pme_n(phy2_pme_n),

    .phy2_mdc(phy2_mdc),
    .phy2_mdio(phy2_mdio)
);



endmodule

`resetall