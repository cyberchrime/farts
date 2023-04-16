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
 * RGMII Stream to PCAP Stream converter
 */
module dma_controller #
(
    // Width of AXI Lite data interface in bits
    parameter AXIL_DATA_WIDTH = 32,
    // Width of AXI Lite address in bits
    parameter AXIL_ADDR_WIDTH = 12,
    // Width of AXI Lite strobe (width of data bus in words)
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    // Width of AXI Lite data interface in bits
    parameter AXIL_DESC_DATA_WIDTH = 32,
    // Width of AXI Lite address in bits
    parameter AXIL_DESC_ADDR_WIDTH = 12,
    // Width of AXI Lite strobe (width of data bus in words)
    parameter AXIL_DESC_STRB_WIDTH = (AXIL_DESC_DATA_WIDTH/8),
    // Width of AXI4 data output interface in bits
    parameter AXI_DATA_WIDTH = 64,
    // Width of AXI4 wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI4 ID signal
    parameter AXI_ID_WIDTH = 8,
    // Maximum AXI burst length to generate
    parameter AXI_MAX_BURST_LEN = 8,
    // Width of AXI address bus in bits
    parameter AXI_ADDR_WIDTH = 32,
    // Width of AXI stream interfaces in bits
    parameter AXIS_DATA_WIDTH = AXI_DATA_WIDTH,
    // AXI stream tkeep signal width (words per cycle)
    parameter AXIS_KEEP_WIDTH = (AXIS_DATA_WIDTH/8),
    // Use AXI stream tlast signal
    parameter AXIS_LAST_ENABLE = 1,
    // Propagate AXI stream tuser signal
    parameter AXIS_USER_ENABLE = 1,
    // AXI stream tuser signal width
    parameter AXIS_USER_WIDTH = 1,
    // Width of tag field
    parameter TAG_WIDTH = 8,
    // Width of data packets
    parameter LEN_WIDTH = 16
)
(
    input  wire                            clk,
    input  wire                            rst,

    /*
     * AXI4-Stream Slave Interface
     */
    input  wire [AXIS_DATA_WIDTH-1:0]      s_axis_tdata,
    input  wire                            s_axis_tvalid,
    input  wire [AXIS_KEEP_WIDTH-1:0]      s_axis_tkeep,
    input  wire                            s_axis_tlast,
    input  wire [AXIS_USER_WIDTH-1:0]      s_axis_tuser,
    output wire                            s_axis_tready,

    output wire                            irq,

    /*
     * AXI lite slave configuration interface
     */
    input  wire [AXIL_DATA_WIDTH-1:0]      s_axil_awaddr,
    input  wire [2:0]                      s_axil_awprot,
    input  wire                            s_axil_awvalid,
    output wire                            s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0]      s_axil_wdata,
    input  wire [AXIL_STRB_WIDTH-1:0]      s_axil_wstrb,
    input  wire                            s_axil_wvalid,
    output wire                            s_axil_wready,
    output wire [1:0]                      s_axil_bresp,
    output wire                            s_axil_bvalid,
    input  wire                            s_axil_bready,

    input  wire [AXIL_ADDR_WIDTH-1:0]      s_axil_araddr,
    input  wire [2:0]                      s_axil_arprot,
    input  wire                            s_axil_arvalid,
    output wire                            s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0]      s_axil_rdata,
    output wire [1:0]                      s_axil_rresp,
    output wire                            s_axil_rvalid,
    input  wire                            s_axil_rready,


    /*
     * AXI lite slave configuration interface
     */
    input  wire [AXIL_DESC_ADDR_WIDTH-1:0] s_axil_desc_awaddr,
    input  wire [2:0]                      s_axil_desc_awprot,
    input  wire                            s_axil_desc_awvalid,
    output wire                            s_axil_desc_awready,
    input  wire [AXIL_DESC_DATA_WIDTH-1:0] s_axil_desc_wdata,
    input  wire [AXIL_DESC_STRB_WIDTH-1:0] s_axil_desc_wstrb,
    input  wire                            s_axil_desc_wvalid,
    output wire                            s_axil_desc_wready,
    output wire [1:0]                      s_axil_desc_bresp,
    output wire                            s_axil_desc_bvalid,
    input  wire                            s_axil_desc_bready,

    input  wire [AXIL_DESC_ADDR_WIDTH-1:0] s_axil_desc_araddr,
    input  wire [2:0]                      s_axil_desc_arprot,
    input  wire                            s_axil_desc_arvalid,
    output wire                            s_axil_desc_arready,
    output wire [AXIL_DESC_DATA_WIDTH-1:0] s_axil_desc_rdata,
    output wire [1:0]                      s_axil_desc_rresp,
    output wire                            s_axil_desc_rvalid,
    input  wire                            s_axil_desc_rready,


    /*
     * AXI4 Master Interface
     */
    output wire [AXI_ID_WIDTH-1:0]         m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]       m_axi_awaddr,
    output wire [7:0]                      m_axi_awlen,
    output wire [2:0]                      m_axi_awsize,
    output wire [1:0]                      m_axi_awburst,
    output wire                            m_axi_awlock,
    output wire [3:0]                      m_axi_awcache,
    output wire [2:0]                      m_axi_awprot,
    output wire                            m_axi_awvalid,
    input  wire                            m_axi_awready,
    output wire [AXI_DATA_WIDTH-1:0]       m_axi_wdata,
    output wire [AXI_STRB_WIDTH-1:0]       m_axi_wstrb,
    output wire                            m_axi_wlast,
    output wire                            m_axi_wvalid,
    input  wire                            m_axi_wready,
    input  wire [AXI_ID_WIDTH-1:0]         m_axi_bid,
    input  wire [1:0]                      m_axi_bresp,
    input  wire                            m_axi_bvalid,
    output wire                            m_axi_bready
);

parameter BRAM_DATA_WIDTH = 128;
parameter BRAM_WORD_SIZE = BRAM_DATA_WIDTH/8;
parameter BRAM_ADDR_WIDTH = $clog2((2**AXIL_DESC_ADDR_WIDTH)/BRAM_WORD_SIZE);

wire [AXI_ADDR_WIDTH-1:0] csr_axi_dma_addr;
wire csr_enable;
wire csr_soft_reset;
wire csr_soft_reset_done = csr_soft_reset_done_reg;
wire set_interrupt = set_interrupt_reg;
wire status_busy = state_reg != IDLE_STATE;


axil_dma_ctrl_regs # (
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH)
)
axil_dma_ctrl_regs_inst (
    .clk(clk),
    .rst(rst),

    .irq(irq),
    /*
     * AXI lite slave interface
     */
    .s_axil_awaddr(s_axil_awaddr),
    .s_axil_awprot(s_axil_awprot),
    .s_axil_awvalid(s_axil_awvalid),
    .s_axil_awready(s_axil_awready),
    .s_axil_wdata(s_axil_wdata),
    .s_axil_wstrb(s_axil_wstrb),
    .s_axil_wvalid(s_axil_wvalid),
    .s_axil_wready(s_axil_wready),
    .s_axil_bresp(s_axil_bresp),
    .s_axil_bvalid(s_axil_bvalid),
    .s_axil_bready(s_axil_bready),

    .s_axil_araddr(s_axil_araddr),
    .s_axil_arprot(s_axil_arprot),
    .s_axil_arvalid(s_axil_arvalid),
    .s_axil_arready(s_axil_arready),
    .s_axil_rdata(s_axil_rdata),
    .s_axil_rresp(s_axil_rresp),
    .s_axil_rvalid(s_axil_rvalid),
    .s_axil_rready(s_axil_rready),

    .axi_dma_addr(csr_axi_dma_addr),
    .enable(csr_enable),
    .soft_reset(csr_soft_reset),
    .soft_reset_done(csr_soft_reset_done),
    .status_busy(status_busy),
    .set_interrupt(set_interrupt)
);

wire [AXIL_DESC_ADDR_WIDTH-1:0] axil_desc_awaddr;
wire [2:0] axil_desc_awprot;
wire axil_desc_awvalid;
wire axil_desc_awready;
wire [BRAM_DATA_WIDTH-1:0] axil_desc_wdata;
wire [BRAM_WORD_SIZE-1:0] axil_desc_wstrb;
wire axil_desc_wvalid;
wire axil_desc_wready;
wire [1:0] axil_desc_bresp;
wire axil_desc_bvalid;
wire axil_desc_bready;

wire [AXIL_DESC_ADDR_WIDTH-1:0] axil_desc_araddr;
wire [2:0] axil_desc_arprot;
wire axil_desc_arvalid;
wire axil_desc_arready;
wire [BRAM_DATA_WIDTH-1:0] axil_desc_rdata;
wire [1:0] axil_desc_rresp;
wire axil_desc_rvalid;
wire axil_desc_rready;

axil_adapter #
(
    .ADDR_WIDTH(AXIL_DESC_ADDR_WIDTH),
    .S_DATA_WIDTH(AXIL_DESC_DATA_WIDTH),
    .M_DATA_WIDTH(128)
)
axil_adapter_inst (
    .clk(clk),
    .rst(rst),

    .s_axil_awaddr(s_axil_desc_awaddr),
    .s_axil_awprot(s_axil_desc_awprot),
    .s_axil_awvalid(s_axil_desc_awvalid),
    .s_axil_awready(s_axil_desc_awready),
    .s_axil_wdata(s_axil_desc_wdata),
    .s_axil_wstrb(s_axil_desc_wstrb),
    .s_axil_wvalid(s_axil_desc_wvalid),
    .s_axil_wready(s_axil_desc_wready),
    .s_axil_bresp(s_axil_desc_bresp),
    .s_axil_bvalid(s_axil_desc_bvalid),
    .s_axil_bready(s_axil_desc_bready),
    .s_axil_araddr(s_axil_desc_araddr),
    .s_axil_arprot(s_axil_desc_arprot),
    .s_axil_arvalid(s_axil_desc_arvalid),
    .s_axil_arready(s_axil_desc_arready),
    .s_axil_rdata(s_axil_desc_rdata),
    .s_axil_rresp(s_axil_desc_rresp),
    .s_axil_rvalid(s_axil_desc_rvalid),
    .s_axil_rready(s_axil_desc_rready),

    .m_axil_awaddr(axil_desc_awaddr),
    .m_axil_awprot(axil_desc_awprot),
    .m_axil_awvalid(axil_desc_awvalid),
    .m_axil_awready(axil_desc_awready),
    .m_axil_wdata(axil_desc_wdata),
    .m_axil_wstrb(axil_desc_wstrb),
    .m_axil_wvalid(axil_desc_wvalid),
    .m_axil_wready(axil_desc_wready),
    .m_axil_bresp(axil_desc_bresp),
    .m_axil_bvalid(axil_desc_bvalid),
    .m_axil_bready(axil_desc_bready),
    .m_axil_araddr(axil_desc_araddr),
    .m_axil_arprot(axil_desc_arprot),
    .m_axil_arvalid(axil_desc_arvalid),
    .m_axil_arready(axil_desc_arready),
    .m_axil_rdata(axil_desc_rdata),
    .m_axil_rresp(axil_desc_rresp),
    .m_axil_rvalid(axil_desc_rvalid),
    .m_axil_rready(axil_desc_rready)
);

wire [AXI_ADDR_WIDTH-1:0] axis_write_desc_addr = axis_write_desc_addr_reg;
wire [LEN_WIDTH-1:0] axis_write_desc_len = axis_write_desc_len_reg;
wire axis_write_desc_valid = axis_write_desc_valid_reg;
wire axis_write_desc_ready;

wire [LEN_WIDTH-1:0] axis_write_desc_status_len;
wire axis_write_desc_status_valid;

axi_dma_wr #
(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_MAX_BURST_LEN(8),
    .AXIS_LAST_ENABLE(1),
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .AXIS_USER_WIDTH(AXIS_USER_WIDTH),
    .ENABLE_SG(0),
    .ENABLE_UNALIGNED(0)
)
axi_dma_wr_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI write descriptor input
     */
    .s_axis_write_desc_addr({axis_write_desc_addr[AXI_ADDR_WIDTH-1:LEN_WIDTH-1], {LEN_WIDTH-1{1'b0}}}),
    .s_axis_write_desc_len(axis_write_desc_len),
    .s_axis_write_desc_tag(),
    .s_axis_write_desc_valid(axis_write_desc_valid),
    .s_axis_write_desc_ready(axis_write_desc_ready),

    /*
     * AXI write descriptor status output
     */
    .m_axis_write_desc_status_len(axis_write_desc_status_len),
    .m_axis_write_desc_status_tag(),
    .m_axis_write_desc_status_id(),
    .m_axis_write_desc_status_dest(),
    .m_axis_write_desc_status_user(),
    .m_axis_write_desc_status_error(),
    .m_axis_write_desc_status_valid(axis_write_desc_status_valid),

    /*
     * AXI stream write data input
     */
    .s_axis_write_data_tdata(s_axis_tdata),
    .s_axis_write_data_tkeep(s_axis_tkeep),
    .s_axis_write_data_tvalid(s_axis_tvalid),
    .s_axis_write_data_tready(s_axis_tready),
    .s_axis_write_data_tlast(s_axis_tlast),
    .s_axis_write_data_tid(),
    .s_axis_write_data_tdest(),
    .s_axis_write_data_tuser(s_axis_tuser),

    /*
     * AXI master interface
     */
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
    .m_axi_bready(m_axi_bready),

    /*
     * Configuration
     */
    .enable(1'b1), // TODO: check if adjustment required
    .abort(1'b0) // TODO: check if adjustment required
);

wire bram_we = bram_we_reg;
wire [BRAM_ADDR_WIDTH-1:0] bram_addr = bram_addr_reg;
wire [BRAM_DATA_WIDTH-1:0] bram_di;
wire bram_en = bram_en_reg;
wire [BRAM_DATA_WIDTH-1:0] bram_do = axis_desc_pipe_tdata;
wire bram_valid = bram_valid_reg;

wire [BRAM_DATA_WIDTH-1:0] axis_desc_pipe_tdata;
wire axis_desc_pipe_tlast;
wire axis_desc_pipe_tready;

axil_bram #
(
    .DATA_WIDTH(128),
    .ADDR_WIDTH(AXIL_DESC_ADDR_WIDTH),
    .PIPELINE_OUTPUT(0)
)
descriptor_ram (
    .clk(clk),
    .rst(rst),

    .s_axil_awaddr(axil_desc_awaddr),
    .s_axil_awprot(axil_desc_awprot),
    .s_axil_awvalid(axil_desc_awvalid),
    .s_axil_awready(axil_desc_awready),
    .s_axil_wdata(axil_desc_wdata),
    .s_axil_wstrb(axil_desc_wstrb),
    .s_axil_wvalid(axil_desc_wvalid),
    .s_axil_wready(axil_desc_wready),
    .s_axil_bresp(axil_desc_bresp),
    .s_axil_bvalid(axil_desc_bvalid),
    .s_axil_bready(axil_desc_bready),
    .s_axil_araddr(axil_desc_araddr),
    .s_axil_arprot(axil_desc_arprot),
    .s_axil_arvalid(axil_desc_arvalid),
    .s_axil_arready(axil_desc_arready),
    .s_axil_rdata(axil_desc_rdata),
    .s_axil_rresp(axil_desc_rresp),
    .s_axil_rvalid(axil_desc_rvalid),
    .s_axil_rready(axil_desc_rready),

    .bram_we(bram_we),
    .bram_addr(bram_addr),
    .bram_di(bram_di),
    .bram_en(bram_en),
    .bram_do(bram_do)
);

localparam DESC_WORDS = 2;
localparam DESC_WORDS_WIDTH = 64;
localparam DESC_WIDTH = DESC_WORDS_WIDTH * DESC_WORDS;
localparam DESC_LENGTH = DESC_WIDTH / 8;
localparam RD_LENGTH_WIDTH = $clog2(DESC_LENGTH) + 1;

dma_desc_regs # (
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXIS_DATA_WIDTH(128),
    .LEN_WIDTH(LEN_WIDTH),
    .DESC_WORDS(DESC_WORDS),
    .DESC_WORD_WIDTH(DESC_WORDS_WIDTH)
)
dma_desc_regs_inst (
    .clk(clk),
    .rst(rst),

    .data_in(bram_do),
    .data_in_valid(bram_valid),

    .data_out(bram_di),

    .dma_desc_addr(dma_write_desc_addr),
    .dma_desc_length(dma_write_desc_length),
    .dma_desc_empty(dma_write_desc_empty),

    .s_axis_dma_desc_length(axis_desc_mod_len),
    .s_axis_dma_desc_valid(axis_desc_mod_valid)
);

wire [AXI_ADDR_WIDTH-1:0] dma_write_desc_addr;
wire [LEN_WIDTH-1:0] dma_write_desc_length;
wire dma_write_desc_empty;

wire [LEN_WIDTH-1:0] axis_desc_mod_len = axis_desc_mod_len_reg;
wire axis_desc_mod_valid = axis_desc_mod_valid_reg;

reg [AXI_ADDR_WIDTH-1:0] axis_write_desc_addr_reg = {AXI_ADDR_WIDTH{1'b0}};
reg [LEN_WIDTH-1:0] axis_write_desc_len_reg = {LEN_WIDTH{1'b0}};
reg axis_write_desc_valid_reg = 1'b0;

reg [LEN_WIDTH-1:0] axis_desc_mod_len_reg = {LEN_WIDTH{1'b0}};
reg axis_desc_mod_valid_reg = 1'b0;

reg bram_we_reg = 1'b0;
reg [BRAM_ADDR_WIDTH-1:0] bram_addr_reg = {BRAM_ADDR_WIDTH{1'b0}};
reg bram_en_reg = 1'b0;
reg bram_valid_reg = 1'b0;

reg set_interrupt_reg = 1'b0;
reg csr_soft_reset_done_reg = 1'b0;

(* dont_touch = "true" *) reg [2:0] state_reg;
localparam [2:0]
    IDLE_STATE = 3'd0,
    DESC_RECV_STATE = 3'd1,
    DESC_STORE_STATE = 3'd2,
    WRITE_DESC_PREPARE_STATE = 3'd3,
    AWAIT_WRITE_DESC_ACK_STATE = 3'd4,
    WRITE_DATA_STATE = 3'd5,
    UPDATE_DESC_STATE = 3'd6,
    INCR_DESC_STATE = 3'd7;

always @(posedge clk) begin
    if (rst) begin
        state_reg <= IDLE_STATE;
        bram_en_reg <= 1'b0;
        bram_addr_reg <= 0;
    end else begin
        state_reg <= state_reg;
        axis_desc_mod_valid_reg <= 1'b0;
        axis_desc_mod_len_reg <= axis_desc_mod_len_reg;

        set_interrupt_reg <= 1'b0;
        csr_soft_reset_done_reg <= 1'b0;

        bram_addr_reg <= bram_addr_reg;
        bram_en_reg <= 1'b0;
        bram_we_reg <= bram_we_reg;
        bram_valid_reg <= 1'b0;

        axis_write_desc_addr_reg <= axis_write_desc_addr_reg;
        axis_write_desc_len_reg <= axis_write_desc_len_reg;
        axis_write_desc_valid_reg <= axis_write_desc_valid_reg;

        case (state_reg)
            IDLE_STATE: begin
                // Wait until there is some data pending
                if (csr_soft_reset) begin
                    bram_addr_reg <= 0;
                    csr_soft_reset_done_reg <= 1'b1;
                end else if (csr_enable) begin
                    if (s_axis_tvalid) begin
                        bram_en_reg <= 1'b1;
                        bram_we_reg <= 1'b0;

                        state_reg <= DESC_RECV_STATE;
                    end
                end
            end
            DESC_RECV_STATE: begin
                // Receive descriptor from the descriptor RAM
                bram_en_reg <= 1'b0;
                bram_valid_reg <= 1'b1;

                state_reg <= DESC_STORE_STATE;
            end
            DESC_STORE_STATE: begin
                state_reg <= WRITE_DESC_PREPARE_STATE;
            end
            WRITE_DESC_PREPARE_STATE: begin
                if (csr_enable && !csr_soft_reset) begin
                    if (dma_write_desc_empty) begin
                        // Prepare the write descriptor
                        axis_write_desc_addr_reg <= dma_write_desc_addr;
                        axis_write_desc_len_reg <= dma_write_desc_length;
                        axis_write_desc_valid_reg <= 1'b1;

                        state_reg <= AWAIT_WRITE_DESC_ACK_STATE;
                    end else begin
                        // Read descriptor another time
                        bram_en_reg <= 1'b1;
                        bram_we_reg <= 1'b0;

                        state_reg <= DESC_RECV_STATE;
                    end
                end else begin
                    state_reg <= IDLE_STATE;
                end
            end
            AWAIT_WRITE_DESC_ACK_STATE: begin
                // wait until AXI WR interface ack'ed the write descriptor
                if (axis_write_desc_ready) begin
                    axis_write_desc_valid_reg <= 1'b0;

                    state_reg <= WRITE_DATA_STATE;
                end
            end
            WRITE_DATA_STATE: begin
                // wait until the AXI WR interface returned the transmitted length
                if (axis_write_desc_status_valid) begin
                    axis_desc_mod_len_reg <= axis_write_desc_status_len;
                    axis_desc_mod_valid_reg <= 1'b1;

                    state_reg <= UPDATE_DESC_STATE;
                end
            end
            UPDATE_DESC_STATE: begin
                bram_en_reg <= 1'b1;
                bram_we_reg <= 1'b1;

                set_interrupt_reg <= 1'b1;

                state_reg <= INCR_DESC_STATE;
            end
            INCR_DESC_STATE: begin
                bram_we_reg <= 1'b0;
                bram_en_reg <= 1'b0;

                if (csr_enable && !csr_soft_reset) begin
                    bram_addr_reg <= bram_addr_reg + 1;

                    if (s_axis_tvalid) begin
                        bram_en_reg <= 1'b1;
                        bram_we_reg <= 1'b0;

                        state_reg <= DESC_RECV_STATE;
                    end else begin
                        state_reg <= IDLE_STATE;
                    end
                end else begin
                    state_reg <= IDLE_STATE;
                end
            end
        endcase
    end
end

endmodule

`resetall
