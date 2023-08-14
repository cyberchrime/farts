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
module fpga_core #
(
    // target ("SIM", "GENERIC", "XILINX", "ALTERA")
    parameter TARGET = "GENERIC",
    // IODDR style ("IODDR", "IODDR2")
    // Use IODDR for Virtex-4, Virtex-5, Virtex-6, 7 Series, Ultrascale
    // Use IODDR2 for Spartan-6
    parameter IODDR_STYLE = "IODDR",
    // Clock input style ("BUFG", "BUFR", "BUFIO", "BUFIO2")
    // Use BUFR for Virtex-6, 7-series
    // Use BUFG for Virtex-5, Spartan-6, Ultrascale
    parameter CLOCK_INPUT_STYLE = "BUFR",
    // Use 90 degree clock for RGMII transmit ("TRUE", "FALSE")
    parameter USE_CLK90 = "FALSE",
    // Width of AXI data bus in bits

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
    parameter AXIL_MDIO_ADDR_WIDTH = 4,
    parameter AXIL_MDIO_STRB_WIDTH = (AXIL_MDIO_DATA_WIDTH/8),
    parameter MDIO_CLK_PRESCALE = 26,

    parameter AXI_DATA_WIDTH = 32,
    // Width of AXI address bus in bits
    parameter AXI_ADDR_WIDTH = 32,
    // Width of AXI wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI ID signal
    parameter AXI_ID_WIDTH = 8,
    // Width of AXI DEST signal
    parameter AXI_DEST_WIDTH = 8,
    // Maximum AXI burst length to generate
    parameter AXI_MAX_BURST_LEN = 256
)
(
    input wire                                 axi_clk,
    input wire                                 axi_rst,

    input wire                                 counter_clk,
    input wire                                 counter_rst,

    /*
     * AXI master interface
     */
    output wire [AXI_ID_WIDTH-1:0]             m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]           m_axi_awaddr,
    output wire [7:0]                          m_axi_awlen,
    output wire [2:0]                          m_axi_awsize,
    output wire [1:0]                          m_axi_awburst,
    output wire                                m_axi_awlock,
    output wire [3:0]                          m_axi_awcache,
    output wire [2:0]                          m_axi_awprot,
    output wire                                m_axi_awvalid,
    input  wire                                m_axi_awready,
    output wire [AXI_DATA_WIDTH-1:0]           m_axi_wdata,
    output wire [AXI_STRB_WIDTH-1:0]           m_axi_wstrb,
    output wire                                m_axi_wlast,
    output wire                                m_axi_wvalid,
    input  wire                                m_axi_wready,
    input  wire [AXI_ID_WIDTH-1:0]             m_axi_bid,
    input  wire [1:0]                          m_axi_bresp,
    input  wire                                m_axi_bvalid,
    output wire                                m_axi_bready,
    output wire [AXI_ID_WIDTH-1:0]             m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0]           m_axi_araddr,
    output wire [7:0]                          m_axi_arlen,
    output wire [2:0]                          m_axi_arsize,
    output wire [1:0]                          m_axi_arburst,
    output wire                                m_axi_arlock,
    output wire [3:0]                          m_axi_arcache,
    output wire [2:0]                          m_axi_arprot,
    output wire                                m_axi_arvalid,
    input  wire                                m_axi_arready,
    input  wire [AXI_ID_WIDTH-1:0]             m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]           m_axi_rdata,
    input  wire [1:0]                          m_axi_rresp,
    input  wire                                m_axi_rlast,
    input  wire                                m_axi_rvalid,
    output wire                                m_axi_rready,

    output wire                                dma_irq,

    /*
     * AXI lite slave interface
     */
    input  wire [AXIL_DMA_ADDR_WIDTH-1:0]      s_axil_dma_awaddr,
    input  wire [2:0]                          s_axil_dma_awprot,
    input  wire                                s_axil_dma_awvalid,
    output wire                                s_axil_dma_awready,
    input  wire [AXIL_DMA_DATA_WIDTH-1:0]      s_axil_dma_wdata,
    input  wire [3:0]                          s_axil_dma_wstrb,
    input  wire                                s_axil_dma_wvalid,
    output wire                                s_axil_dma_wready,
    output wire [1:0]                          s_axil_dma_bresp,
    output wire                                s_axil_dma_bvalid,
    input  wire                                s_axil_dma_bready,

    input  wire [AXIL_DMA_ADDR_WIDTH-1:0]      s_axil_dma_araddr,
    input  wire [2:0]                          s_axil_dma_arprot,
    input  wire                                s_axil_dma_arvalid,
    output wire                                s_axil_dma_arready,
    output wire [AXIL_DMA_DATA_WIDTH-1:0]      s_axil_dma_rdata,
    output wire [1:0]                          s_axil_dma_rresp,
    output wire                                s_axil_dma_rvalid,
    input  wire                                s_axil_dma_rready,

    input  wire [AXIL_DMA_DESC_ADDR_WIDTH-1:0] s_axil_dma_desc_awaddr,
    input  wire [2:0]                          s_axil_dma_desc_awprot,
    input  wire                                s_axil_dma_desc_awvalid,
    output wire                                s_axil_dma_desc_awready,
    input  wire [AXIL_DMA_DESC_DATA_WIDTH-1:0] s_axil_dma_desc_wdata,
    input  wire [3:0]                          s_axil_dma_desc_wstrb,
    input  wire                                s_axil_dma_desc_wvalid,
    output wire                                s_axil_dma_desc_wready,
    output wire [1:0]                          s_axil_dma_desc_bresp,
    output wire                                s_axil_dma_desc_bvalid,
    input  wire                                s_axil_dma_desc_bready,

    input  wire [AXIL_DMA_DESC_ADDR_WIDTH-1:0] s_axil_dma_desc_araddr,
    input  wire [2:0]                          s_axil_dma_desc_arprot,
    input  wire                                s_axil_dma_desc_arvalid,
    output wire                                s_axil_dma_desc_arready,
    output wire [AXIL_DMA_DESC_DATA_WIDTH-1:0] s_axil_dma_desc_rdata,
    output wire [1:0]                          s_axil_dma_desc_rresp,
    output wire                                s_axil_dma_desc_rvalid,
    input  wire                                s_axil_dma_desc_rready,

    input  wire [AXIL_MAC_ADDR_WIDTH-1:0]      s_axil_mac_awaddr,
    input  wire [2:0]                          s_axil_mac_awprot,
    input  wire                                s_axil_mac_awvalid,
    output wire                                s_axil_mac_awready,
    input  wire [AXIL_MAC_DATA_WIDTH-1:0]      s_axil_mac_wdata,
    input  wire [3:0]                          s_axil_mac_wstrb,
    input  wire                                s_axil_mac_wvalid,
    output wire                                s_axil_mac_wready,
    output wire [1:0]                          s_axil_mac_bresp,
    output wire                                s_axil_mac_bvalid,
    input  wire                                s_axil_mac_bready,

    input  wire [AXIL_MAC_ADDR_WIDTH-1:0]      s_axil_mac_araddr,
    input  wire [2:0]                          s_axil_mac_arprot,
    input  wire                                s_axil_mac_arvalid,
    output wire                                s_axil_mac_arready,
    output wire [AXIL_MAC_DATA_WIDTH-1:0]      s_axil_mac_rdata,
    output wire [1:0]                          s_axil_mac_rresp,
    output wire                                s_axil_mac_rvalid,
    input  wire                                s_axil_mac_rready,


    input  wire [AXIL_MDIO_ADDR_WIDTH-1:0]     s_axil_mdio_awaddr,
    input  wire [2:0]                          s_axil_mdio_awprot,
    input  wire                                s_axil_mdio_awvalid,
    output wire                                s_axil_mdio_awready,
    input  wire [AXIL_MDIO_DATA_WIDTH-1:0]     s_axil_mdio_wdata,
    input  wire [3:0]                          s_axil_mdio_wstrb,
    input  wire                                s_axil_mdio_wvalid,
    output wire                                s_axil_mdio_wready,
    output wire [1:0]                          s_axil_mdio_bresp,
    output wire                                s_axil_mdio_bvalid,
    input  wire                                s_axil_mdio_bready,

    input  wire [AXIL_MDIO_ADDR_WIDTH-1:0]     s_axil_mdio_araddr,
    input  wire [2:0]                          s_axil_mdio_arprot,
    input  wire                                s_axil_mdio_arvalid,
    output wire                                s_axil_mdio_arready,
    output wire [AXIL_MDIO_DATA_WIDTH-1:0]     s_axil_mdio_rdata,
    output wire [1:0]                          s_axil_mdio_rresp,
    output wire                                s_axil_mdio_rvalid,
    input  wire                                s_axil_mdio_rready,

    /*
     * Ethernet PORT 1: 1000BASE-T RGMII
     */
    input  wire                                phy1_rgmii_rx_clk,
    input  wire [3:0]                          phy1_rgmii_rxd,
    input  wire                                phy1_rgmii_rx_ctl,
    output wire                                phy1_rgmii_tx_clk,
    output wire [3:0]                          phy1_rgmii_txd,
    output wire                                phy1_rgmii_tx_ctl,
    output wire                                phy1_reset_n,
    input  wire                                phy1_int_n,
    input  wire                                phy1_pme_n,

    output wire                                phy1_mdc,
    inout  wire                                phy1_mdio,

    /*
     * Ethernet PORT 2: 1000BASE-T RGMII
     */
    input  wire                                phy2_rgmii_rx_clk,
    input  wire [3:0]                          phy2_rgmii_rxd,
    input  wire                                phy2_rgmii_rx_ctl,
    output wire                                phy2_rgmii_tx_clk,
    output wire [3:0]                          phy2_rgmii_txd,
    output wire                                phy2_rgmii_tx_ctl,
    output wire                                phy2_reset_n,
    input  wire                                phy2_int_n,
    input  wire                                phy2_pme_n,

    output wire                                phy2_mdc,
    inout  wire                                phy2_mdio
);

localparam LENGTH_WIDTH = 12;

localparam AXIS_DATA_WIDTH = 8;
localparam AXIS_USER_WIDTH = 1;

wire [AXI_DATA_WIDTH-1:0] axis_tdata, axis1_tdata, axis2_tdata;
wire axis_tvalid, axis1_tvalid, axis2_tvalid;
wire axis_tlast, axis1_tlast, axis2_tlast;
wire [AXI_STRB_WIDTH-1:0] axis_tkeep, axis1_tkeep, axis2_tkeep;
wire [AXIS_USER_WIDTH-1:0] axis_tuser, axis1_tuser, axis2_tuser;
wire axis_tready, axis1_tready, axis2_tready;

wire [31:0] ts_nsec_gray;
wire [31:0] ts_sec_gray;

wire ctrl_mac_enable;
wire ctrl_mii_select;

pcap_clock
pcap_clk_inst (
    .clk(counter_clk),
    .rst(counter_rst),
    .nsec(ts_nsec_gray),
    .sec(ts_sec_gray)
);

wire status_busy1, status_busy2;

wire fifo1_overflow, fifo2_overflow;
wire fifo1_bad_frame, fifo2_bad_frame;
wire fifo1_good_frame, fifo2_good_frame;
wire mac1_start_frame, mac2_start_frame;
wire mac1_bad_frame, mac2_bad_frame;
wire mac1_bad_fcs, mac2_bad_fcs;

rgmii_pcap #
(
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_USER_WIDTH(AXIS_USER_WIDTH),
    .FRAME_LEN_WIDTH(LENGTH_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .TARGET(TARGET),
    .IODDR_STYLE(IODDR_STYLE),
    .CLOCK_INPUT_STYLE(CLOCK_INPUT_STYLE)
)
rgmii1_pcap_inst (
    .axi_clk(axi_clk),
    .axi_rst(axi_rst),

    .counter_clk(counter_clk),
    .counter_rst(counter_rst),

    .rgmii_rx_clk(phy1_rgmii_rx_clk),
    .rgmii_rxd(phy1_rgmii_rxd),
    .rgmii_rx_ctl(phy1_rgmii_rx_ctl),

    .m_axis_tdata(axis1_tdata),
    .m_axis_tvalid(axis1_tvalid),
    .m_axis_tlast(axis1_tlast),
    .m_axis_tuser(axis1_tuser),
    .m_axis_tkeep(axis1_tkeep),
    .m_axis_tready(axis1_tready),

    .fifo_overflow(fifo1_overflow),
    .fifo_bad_frame(fifo1_bad_frame),
    .fifo_good_frame(fifo1_good_frame),
    .start_packet(mac1_start_frame),
    .bad_frame(mac1_bad_frame),
    .bad_fcs(mac1_bad_fcs),

    .ts_sec_gray(ts_sec_gray),
    .ts_nsec_gray(ts_nsec_gray),

    .busy(status_busy1),

    .enable(ctrl_mac_enable),
    .mii_select(ctrl_mii_select)
);

rgmii_pcap #
(
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_USER_WIDTH(AXIS_USER_WIDTH),
    .FRAME_LEN_WIDTH(LENGTH_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .TARGET(TARGET),
    .IODDR_STYLE(IODDR_STYLE),
    .CLOCK_INPUT_STYLE(CLOCK_INPUT_STYLE)
)
rgmii2_pcap_inst (
    .axi_clk(axi_clk),
    .axi_rst(axi_rst),

    .counter_clk(counter_clk),
    .counter_rst(counter_rst),

    .rgmii_rx_clk(phy2_rgmii_rx_clk),
    .rgmii_rxd(phy2_rgmii_rxd),
    .rgmii_rx_ctl(phy2_rgmii_rx_ctl),

    .m_axis_tdata(axis2_tdata),
    .m_axis_tvalid(axis2_tvalid),
    .m_axis_tlast(axis2_tlast),
    .m_axis_tuser(axis2_tuser),
    .m_axis_tkeep(axis2_tkeep),
    .m_axis_tready(axis2_tready),

    .fifo_overflow(fifo2_overflow),
    .fifo_bad_frame(fifo2_bad_frame),
    .fifo_good_frame(fifo2_good_frame),
    .start_packet(mac2_start_frame),
    .bad_frame(mac2_bad_frame),
    .bad_fcs(mac2_bad_fcs),

    .ts_sec_gray(ts_sec_gray),
    .ts_nsec_gray(ts_nsec_gray),

    .busy(status_busy2),

    .enable(ctrl_mac_enable),
    .mii_select(ctrl_mii_select)
);

axis_arb_mux #
(
    .S_COUNT(2),
    .DATA_WIDTH(AXI_DATA_WIDTH),
    .KEEP_ENABLE(1),
    .USER_WIDTH(AXIS_USER_WIDTH),
    .ID_ENABLE(0),
    .S_ID_WIDTH(AXI_ID_WIDTH),
    .DEST_ENABLE(0),
    .DEST_WIDTH(AXI_DEST_WIDTH),
    .USER_ENABLE(0),
    .LAST_ENABLE(1),
    .ARB_TYPE_ROUND_ROBIN(1),
    .ARB_LSB_HIGH_PRIORITY(0)
)
axis_arb_mux_inst (
    .clk(axi_clk),
    .rst(axi_rst),

    .s_axis_tdata({axis2_tdata, axis1_tdata}),
    .s_axis_tvalid({axis2_tvalid, axis1_tvalid}),
    .s_axis_tready({axis2_tready, axis1_tready}),
    .s_axis_tlast({axis2_tlast, axis1_tlast}),
    .s_axis_tkeep({axis2_tkeep, axis1_tkeep}),
    .s_axis_tuser({axis2_tuser, axis1_tuser}),
    .s_axis_tid({{AXI_ID_WIDTH{1'b0}}, {AXI_ID_WIDTH{1'b0}}}),
    .s_axis_tdest({{AXI_DEST_WIDTH{1'b0}}, {AXI_DEST_WIDTH{1'b0}}}),

    .m_axis_tdata(axis_tdata),
    .m_axis_tvalid(axis_tvalid),
    .m_axis_tready(axis_tready),
    .m_axis_tlast(axis_tlast),
    .m_axis_tkeep(axis_tkeep),
    .m_axis_tuser(axis_tuser)
);

dma_controller # (
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXIS_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXIS_LAST_ENABLE(1),
    .AXIS_USER_ENABLE(1),
    .AXIS_USER_WIDTH(AXIS_USER_WIDTH),
    .AXIL_DATA_WIDTH(AXIL_DMA_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_DMA_ADDR_WIDTH),
    .AXIL_DESC_DATA_WIDTH(AXIL_DMA_DESC_DATA_WIDTH),
    .AXIL_DESC_ADDR_WIDTH(AXIL_DMA_DESC_ADDR_WIDTH),
    .LEN_WIDTH(LENGTH_WIDTH),
    .TAG_WIDTH(8)
)
dma_controller_inst (
    .clk(axi_clk),
    .rst(axi_rst),

    .s_axis_tdata(axis_tdata),
    .s_axis_tvalid(axis_tvalid),
    .s_axis_tlast(axis_tlast),
    .s_axis_tuser(axis_tuser),
    .s_axis_tkeep(axis_tkeep),
    .s_axis_tready(axis_tready),

    .s_axil_awaddr(s_axil_dma_awaddr),
    .s_axil_awprot(s_axil_dma_awprot),
    .s_axil_awvalid(s_axil_dma_awvalid),
    .s_axil_awready(s_axil_dma_awready),
    .s_axil_wdata(s_axil_dma_wdata),
    .s_axil_wstrb(s_axil_dma_wstrb),
    .s_axil_wvalid(s_axil_dma_wvalid),
    .s_axil_wready(s_axil_dma_wready),
    .s_axil_bresp(s_axil_dma_bresp),
    .s_axil_bvalid(s_axil_dma_bvalid),
    .s_axil_bready(s_axil_dma_bready),

    .s_axil_araddr(s_axil_dma_araddr),
    .s_axil_arprot(s_axil_dma_arprot),
    .s_axil_arvalid(s_axil_dma_arvalid),
    .s_axil_arready(s_axil_dma_arready),
    .s_axil_rdata(s_axil_dma_rdata),
    .s_axil_rresp(s_axil_dma_rresp),
    .s_axil_rvalid(s_axil_dma_rvalid),
    .s_axil_rready(s_axil_dma_rready),

    .s_axil_desc_awaddr(s_axil_dma_desc_awaddr),
    .s_axil_desc_awprot(s_axil_dma_desc_awprot),
    .s_axil_desc_awvalid(s_axil_dma_desc_awvalid),
    .s_axil_desc_awready(s_axil_dma_desc_awready),
    .s_axil_desc_wdata(s_axil_dma_desc_wdata),
    .s_axil_desc_wstrb(s_axil_dma_desc_wstrb),
    .s_axil_desc_wvalid(s_axil_dma_desc_wvalid),
    .s_axil_desc_wready(s_axil_dma_desc_wready),
    .s_axil_desc_bresp(s_axil_dma_desc_bresp),
    .s_axil_desc_bvalid(s_axil_dma_desc_bvalid),
    .s_axil_desc_bready(s_axil_dma_desc_bready),

    .s_axil_desc_araddr(s_axil_dma_desc_araddr),
    .s_axil_desc_arprot(s_axil_dma_desc_arprot),
    .s_axil_desc_arvalid(s_axil_dma_desc_arvalid),
    .s_axil_desc_arready(s_axil_dma_desc_arready),
    .s_axil_desc_rdata(s_axil_dma_desc_rdata),
    .s_axil_desc_rresp(s_axil_dma_desc_rresp),
    .s_axil_desc_rvalid(s_axil_dma_desc_rvalid),
    .s_axil_desc_rready(s_axil_dma_desc_rready),

    .irq(dma_irq),

    .m_axi_awid(m_axi_awid),
    .m_axi_awaddr(m_axi_awaddr),
    .m_axi_awlen(m_axi_awlen),
    .m_axi_awsize(m_axi_awsize),
    .m_axi_awburst(m_axi_awburst),
    .m_axi_awlock(m_axi_awlock),
    .m_axi_awcache(m_axi_awcache),
    .m_axi_awprot(m_axi_awprot),
    .m_axi_awvalid(m_axi_awvalid),
    .m_axi_awready(m_axi_awready),
    .m_axi_wdata(m_axi_wdata),
    .m_axi_wstrb(m_axi_wstrb),
    .m_axi_wlast(m_axi_wlast),
    .m_axi_wvalid(m_axi_wvalid),
    .m_axi_wready(m_axi_wready),
    .m_axi_bid(m_axi_bid),
    .m_axi_bresp(m_axi_bresp),
    .m_axi_bvalid(m_axi_bvalid),
    .m_axi_bready(m_axi_bready)
);

axil_mdio_controller #
(
    .AXIL_DATA_WIDTH(AXIL_MDIO_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_MDIO_ADDR_WIDTH),
    .MDIO_INTERFACES(2),
    .MDIO_CLK_PRESCALE(MDIO_CLK_PRESCALE)
)
axil_mdio_controller (
    .clk(axi_clk),
    .rst(axi_rst),

    .s_axil_awaddr(s_axil_mdio_awaddr),
    .s_axil_awprot(s_axil_mdio_awprot),
    .s_axil_awvalid(s_axil_mdio_awvalid),
    .s_axil_awready(s_axil_mdio_awready),
    .s_axil_wdata(s_axil_mdio_wdata),
    .s_axil_wstrb(s_axil_mdio_wstrb),
    .s_axil_wvalid(s_axil_mdio_wvalid),
    .s_axil_wready(s_axil_mdio_wready),
    .s_axil_bresp(s_axil_mdio_bresp),
    .s_axil_bvalid(s_axil_mdio_bvalid),
    .s_axil_bready(s_axil_mdio_bready),

    .s_axil_araddr(s_axil_mdio_araddr),
    .s_axil_arprot(s_axil_mdio_arprot),
    .s_axil_arvalid(s_axil_mdio_arvalid),
    .s_axil_arready(s_axil_mdio_arready),
    .s_axil_rdata(s_axil_mdio_rdata),
    .s_axil_rresp(s_axil_mdio_rresp),
    .s_axil_rvalid(s_axil_mdio_rvalid),
    .s_axil_rready(s_axil_mdio_rready),

    .mdc({phy2_mdc, phy1_mdc}),
    .mdio({phy2_mdio, phy1_mdio})
);

wire status_buffers_empty = !(axis1_tvalid || axis2_tvalid || axis_tvalid);
wire status_busy = status_busy1 || status_busy2;

axil_mac_ctrl_regs #
(
    .AXIL_DATA_WIDTH(AXIL_MAC_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_MAC_ADDR_WIDTH)
)
axil_mac_controller (
    .clk(axi_clk),
    .rst(axi_rst),

    .s_axil_awaddr(s_axil_mac_awaddr),
    .s_axil_awprot(s_axil_mac_awprot),
    .s_axil_awvalid(s_axil_mac_awvalid),
    .s_axil_awready(s_axil_mac_awready),
    .s_axil_wdata(s_axil_mac_wdata),
    .s_axil_wstrb(s_axil_mac_wstrb),
    .s_axil_wvalid(s_axil_mac_wvalid),
    .s_axil_wready(s_axil_mac_wready),
    .s_axil_bresp(s_axil_mac_bresp),
    .s_axil_bvalid(s_axil_mac_bvalid),
    .s_axil_bready(s_axil_mac_bready),

    .s_axil_araddr(s_axil_mac_araddr),
    .s_axil_arprot(s_axil_mac_arprot),
    .s_axil_arvalid(s_axil_mac_arvalid),
    .s_axil_arready(s_axil_mac_arready),
    .s_axil_rdata(s_axil_mac_rdata),
    .s_axil_rresp(s_axil_mac_rresp),
    .s_axil_rvalid(s_axil_mac_rvalid),
    .s_axil_rready(s_axil_mac_rready),

    .mac1_start_frame(mac1_start_frame),
    .mac1_bad_frame(mac1_bad_frame),
    .mac1_bad_fcs(mac1_bad_fcs),
    .fifo1_bad_frame(fifo1_bad_frame),
    .fifo1_good_frame(fifo1_good_frame),
    .fifo1_overflow(fifo1_overflow),

    .mac2_start_frame(mac2_start_frame),
    .mac2_bad_frame(mac2_bad_frame),
    .mac2_bad_fcs(mac2_bad_fcs),
    .fifo2_bad_frame(fifo2_bad_frame),
    .fifo2_good_frame(fifo2_good_frame),
    .fifo2_overflow(fifo2_overflow),

    .status_buffers_empty(status_buffers_empty),
    .status_busy(status_busy),

    .ctrl_enable(ctrl_mac_enable),
    .ctrl_mii_select(ctrl_mii_select)
);

phy_bridge #(
    .TARGET(TARGET),
    .IODDR_STYLE(IODDR_STYLE),
    .CLOCK_INPUT_STYLE(CLOCK_INPUT_STYLE),
    .USE_CLK90(USE_CLK90)
)
phy_bridge_inst (
    // Ethernet PORT 1: 1000BASE-T RGMII
    .phy1_rgmii_rx_clk(phy1_rgmii_rx_clk),
    .phy1_rgmii_rxd(phy1_rgmii_rxd),
    .phy1_rgmii_rx_ctl(phy1_rgmii_rx_ctl),
    .phy1_rgmii_tx_clk(phy1_rgmii_tx_clk),
    .phy1_rgmii_txd(phy1_rgmii_txd),
    .phy1_rgmii_tx_ctl(phy1_rgmii_tx_ctl),

    // Ethernet PORT 2: 1000BASE-T RGMII
    .phy2_rgmii_rx_clk(phy2_rgmii_rx_clk),
    .phy2_rgmii_rxd(phy2_rgmii_rxd),
    .phy2_rgmii_rx_ctl(phy2_rgmii_rx_ctl),
    .phy2_rgmii_tx_clk(phy2_rgmii_tx_clk),
    .phy2_rgmii_txd(phy2_rgmii_txd),
    .phy2_rgmii_tx_ctl(phy2_rgmii_tx_ctl)
);

endmodule

`resetall
