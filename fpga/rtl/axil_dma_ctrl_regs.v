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
 * Register for DMA control, accessible with AXI4 lite
 */
module axil_dma_ctrl_regs #
(
    // Width of AXI Lite data interface in bits
    parameter AXIL_DATA_WIDTH = 32,
    // Width of AXI Lite address in bits
    parameter AXIL_ADDR_WIDTH = 12,
    // Width of AXI Lite strobe (width of data bus in words)
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    // Width of DMA length descriptor field
    parameter LEN_WIDTH = 12,
    // Width of AXI address bus in bits
    parameter AXI_ADDR_WIDTH = 32
)
(
    input  wire                       clk,
    input  wire                       rst,

    output wire                       irq,

    /*
     * AXI lite slave interface
     */
    input  wire [AXIL_DATA_WIDTH-1:0] s_axil_awaddr,
    input  wire [2:0]                 s_axil_awprot,
    input  wire                       s_axil_awvalid,
    output wire                       s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0] s_axil_wdata,
    input  wire [AXIL_STRB_WIDTH-1:0] s_axil_wstrb,
    input  wire                       s_axil_wvalid,
    output wire                       s_axil_wready,
    output wire [1:0]                 s_axil_bresp,
    output wire                       s_axil_bvalid,
    input  wire                       s_axil_bready,

    input  wire [AXIL_ADDR_WIDTH-1:0] s_axil_araddr,
    input  wire [2:0]                 s_axil_arprot,
    input  wire                       s_axil_arvalid,
    output wire                       s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0] s_axil_rdata,
    output wire [1:0]                 s_axil_rresp,
    output wire                       s_axil_rvalid,
    input  wire                       s_axil_rready,

    /*
     * Control lines
     */

    output wire [AXI_ADDR_WIDTH-1:0]  axi_dma_addr,
    output wire                       enable,
    output wire                       soft_reset,
    input  wire                       soft_reset_done,
    input  wire                       status_busy,
    input  wire                       set_interrupt
);


reg bvalid_reg = 1'b0;
reg [1:0] bresp_reg = 2'b0;
reg wready_reg = 1'b0;

assign s_axil_bvalid = bvalid_reg;
assign s_axil_bresp = bresp_reg;
assign s_axil_awready = wready_reg;
assign s_axil_wready = wready_reg;

assign s_axil_rresp = rresp_reg;
assign s_axil_rvalid = rvalid_reg;
assign s_axil_arready = arready_reg;
assign s_axil_rdata = rdata_reg;

assign irq = irq_pending_reg;
assign enable = enable_reg;
assign axi_dma_addr = dma_write_desc_adr;

localparam [AXIL_ADDR_WIDTH-1:0]
    DMA_ADR_ID = 8'd0, // RW, address where data is written to
    DMA_LENGTH_ID = 8'd4, // RW, set to enable DMA
    DMA_CTRL_ID = 8'd8,
    DMA_STATUS_ID = 8'd12,
    DMA_IRQ_TIME_ID = 8'd16,
    DMA_PACKET_COUNT_ID = 8'd20;

reg [AXI_ADDR_WIDTH-1:0] dma_write_desc_adr = {AXI_ADDR_WIDTH{1'b0}};
reg [LEN_WIDTH-1:0] dma_write_len_reg = {LEN_WIDTH{1'b0}};
reg dma_write_enable_reg = 1'b0;

reg irq_pending_reg = 1'b0;

reg enable_reg = 1'b0;
reg soft_reset_reg = 1'b0;
reg irq_enable_reg = 1'b0;
reg [31:0] irq_time_reg = 32'b0;
reg [31:0] packet_count_reg = 32'b0;

assign soft_reset = soft_reset_reg;

// TODO: explain simultanious RW behavior

// WRITE
always @(posedge clk) begin
    wready_reg <= wready_reg;
    bvalid_reg <= bvalid_reg;

    irq_pending_reg <= irq_pending_reg;
    irq_enable_reg <= irq_enable_reg;
    irq_time_reg <= irq_time_reg + irq_pending_reg;
    soft_reset_reg <= soft_reset_reg & !soft_reset_done;

    if (rst) begin
        dma_write_desc_adr <= {AXI_ADDR_WIDTH{1'b0}};
        dma_write_len_reg <= {LEN_WIDTH{1'b0}};
        bvalid_reg <= 1'b0;

        enable_reg <= 1'b0;
        soft_reset_reg <= 1'b0;
        irq_enable_reg <= 1'b0;
        irq_pending_reg <= 1'b0;
        irq_time_reg <= 32'b0;
        packet_count_reg <= 32'b0;
    end else begin
        if (soft_reset_reg) begin
            irq_pending_reg <= 1'b0;
            packet_count_reg <= 32'b0;
        end else begin
            packet_count_reg <= packet_count_reg + set_interrupt;
        end

        if (s_axil_wvalid && s_axil_awvalid && s_axil_bready && !wready_reg && !bvalid_reg) begin
            wready_reg <= 1'b1;

            case (s_axil_awaddr)
                DMA_ADR_ID: begin
                    dma_write_desc_adr <= s_axil_wdata;
                    bresp_reg <= 2'b00;
                end
                DMA_LENGTH_ID: begin
                    dma_write_len_reg <= s_axil_wdata[LEN_WIDTH-1:0];
                    bresp_reg <= 2'b00;
                end
                DMA_CTRL_ID: begin
                    enable_reg <= s_axil_wdata[0];
                    soft_reset_reg <= s_axil_wdata[1];
                    irq_enable_reg <= s_axil_wdata[2];
                    bresp_reg <= 2'b00;
                end
                DMA_STATUS_ID: begin
                    if (s_axil_wdata[1]) begin
                        irq_pending_reg <= 1'b0;
                    end
                    bresp_reg <= 2'b00;
                end
                DMA_IRQ_TIME_ID: begin
                    irq_time_reg <= s_axil_wdata;
                    bresp_reg <= 2'b00;
                end
                DMA_PACKET_COUNT_ID: begin
                    packet_count_reg <= s_axil_wdata;
                    bresp_reg <= 2'b00;
                end
                default: begin
                    bresp_reg <= 2'b11;
                end
            endcase
        end else if (wready_reg && s_axil_bready) begin
            wready_reg <= 1'b0;
            bvalid_reg <= 1'b1;
        end else if (bvalid_reg) begin
            bvalid_reg <= 1'b0;
        end
    end

    if (set_interrupt && irq_enable_reg) begin
        irq_pending_reg <= 1'b1;
    end
end


reg [1:0] rresp_reg = 2'b0;
reg rvalid_reg = 1'b0;
reg arready_reg = 1'b0;
reg [AXIL_DATA_WIDTH-1:0] rdata_reg = {AXIL_DATA_WIDTH{1'b0}};

reg busy_reg = 1'b0;

// READ
always @(posedge clk) begin
    rvalid_reg <= 1'b0;
    rdata_reg <= rdata_reg;
    rresp_reg <= rresp_reg;
    arready_reg <= arready_reg;

    busy_reg <= status_busy;

    if (s_axil_arvalid && s_axil_rready && !rvalid_reg) begin
        rvalid_reg <= 1'b1;
        arready_reg <= 1'b1;

        case (s_axil_araddr)
            DMA_ADR_ID: begin
                rdata_reg <= dma_write_desc_adr;
                rresp_reg <= 2'b00;
            end
            DMA_LENGTH_ID: begin
                rdata_reg <= {{(32-LEN_WIDTH){1'b0}}, dma_write_len_reg};
                rresp_reg <= 2'b00;
            end
            DMA_CTRL_ID: begin
                rdata_reg <= {29'b0, irq_enable_reg, soft_reset_reg, enable_reg};
                rresp_reg <= 2'b00;
            end
            DMA_STATUS_ID: begin
                rdata_reg <= {30'b0, irq_pending_reg, busy_reg};
                rresp_reg <= 2'b00;
            end
            DMA_IRQ_TIME_ID: begin
                rdata_reg <= irq_time_reg;
                rresp_reg <= 2'b00;
            end
            DMA_PACKET_COUNT_ID: begin
                rdata_reg <= packet_count_reg;
                rresp_reg <= 2'b00;
            end
            default: begin
                rdata_reg <= {AXIL_DATA_WIDTH{1'b0}};
                rresp_reg <= 2'b11;
            end
        endcase
    end

    if (rst) begin
        rvalid_reg <= 1'b0;
        arready_reg <= 1'b0;
    end
end

endmodule

`resetall
