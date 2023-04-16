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
module axil_ctrl_regs #
(
    parameter AXIL_DATA_WIDTH = 32,
    parameter AXIL_ADDR_WIDTH = 12,
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    // Width of AXI address bus in bits
    parameter AXI_ADDR_WIDTH = 32
)
(
    input  wire                       clk,
    input  wire                       rst,

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

    output wire                       mii_mode,

    output wire [AXI_ADDR_WIDTH-1:0]  m_axis_dma_write_adr,
    output wire                       m_axis_dma_write_tvalid,
    input  wire                       m_axis_dma_write_tready
);


reg bvalid_reg = 1'b0, bvalid_next;
reg [1:0] bresp_reg = 2'b0, bresp_next;
reg wready_reg = 1'b0, wready_next;

assign s_axil_bvalid = bvalid_reg;
assign s_axil_bresp = bresp_reg;
assign s_axil_awready = wready_reg;
assign s_axil_wready = wready_reg;

assign s_axil_rresp = rresp_reg;
assign s_axil_rvalid = rvalid_reg;
assign s_axil_arready = arready_reg;
assign s_axil_rdata = rdata_reg;

localparam [AXIL_ADDR_WIDTH-1:0]
    MAC_CONFIG_ID = 4'd0,
    DMA_WRITE_ADR_ID = 4'd4, // RW, address where data is written to
    DMA_WRITE_ENABLE_ID = 4'd8; // RW, set first bit to enable DMA

reg mii_mode_reg = 1'b0, mii_mode_next;

reg [AXI_ADDR_WIDTH-1:0] dma_write_adr_reg = {AXI_ADDR_WIDTH{1'b0}}, dma_write_adr_next;
reg dma_write_enable_reg = 1'b0, dma_write_enable_next;

// TODO: explain simultanious RW behavior


// WRITE
always @(*)begin
    wready_next = wready_reg;
    bvalid_next = bvalid_reg;

    mii_mode_next = mii_mode_reg;
    dma_write_adr_next = dma_write_adr_reg;
    dma_write_enable_next = dma_write_enable_reg && !m_axis_dma_write_tready;
    // disable DMA after each successful DMA memory access

    if (rst) begin
        dma_write_adr_next = {AXIL_DATA_WIDTH{1'b0}};
        dma_write_enable_next = {AXIL_DATA_WIDTH{1'b0}};
        bvalid_next = 1'b0;
    end else begin
        if (s_axil_wvalid && s_axil_awvalid && s_axil_bready && !wready_next && !bvalid_next) begin
            wready_next = 1'b1;

            case (s_axil_awaddr)
                MAC_CONFIG_ID: begin
                    mii_mode_next = s_axil_wdata[0];
                end
                DMA_WRITE_ADR_ID: begin
                    dma_write_adr_next = s_axil_wdata;
                    bresp_next = 2'b00;
                end
                DMA_WRITE_ENABLE_ID: begin
                    dma_write_enable_next = s_axil_wdata[0];
                    bresp_next = 2'b00;
                end
                default: begin
                    bresp_next = 2'b11;
                end
            endcase
        end else if (wready_reg && s_axil_bready) begin
            wready_next = 1'b0;
            bvalid_next = 1'b1;
        end else if (bvalid_reg) begin
            bvalid_next = 1'b0;
        end
    end
end

// WRITE
always @(posedge clk) begin
    mii_mode_reg <= mii_mode_next;
    dma_write_adr_reg <= dma_write_adr_next;
    dma_write_enable_reg <= dma_write_enable_next;
    bvalid_reg <= bvalid_next;
    bresp_reg <= bresp_next;
    wready_reg <= wready_next;
end


reg [1:0] rresp_reg = 2'b0, rresp_next;
reg rvalid_reg = 1'b0, rvalid_next;
reg arready_reg = 1'b0, arready_next;
reg [AXIL_DATA_WIDTH-1:0] rdata_reg = {AXIL_DATA_WIDTH{1'b0}}, rdata_next;

// READ
always @* begin
    rvalid_next = 1'b0;
    rdata_next = rdata_reg;
    rresp_next = rresp_reg;
    arready_next = arready_reg;

    if (s_axil_arvalid && s_axil_rready && !rvalid_reg) begin
        rvalid_next = 1'b1;
        arready_next = 1'b1;

        case (s_axil_araddr)
            MAC_CONFIG_ID: begin
                rdata_next = {31'b0, mii_mode_reg};
                rresp_next = 2'b00;
            end
            DMA_WRITE_ADR_ID: begin
                rdata_next = dma_write_adr_reg;
                rresp_next = 2'b00;
            end
            DMA_WRITE_ENABLE_ID: begin
                rdata_next = {{(AXIL_DATA_WIDTH-1){1'b0}}, dma_write_enable_reg};
                rresp_next = 2'b00;
            end
            default: begin
                rdata_next = {AXIL_DATA_WIDTH{1'b0}};
                rresp_next = 2'b11;
            end
        endcase
    end

    if (rst) begin
        rvalid_next = 1'b0;
        arready_next = 1'b0;
    end
end

// READ
always @(posedge clk) begin
    arready_reg <= arready_next;
    rdata_reg <= rdata_next;
    rvalid_reg <= rvalid_next;
    rresp_reg <= rresp_next;
end

assign mii_mode = mii_mode_reg;

reg m_axis_dma_write_tvalid_reg = 1'b0;
reg [AXI_ADDR_WIDTH-1:0] m_axis_dma_write_adr_reg;

assign m_axis_dma_write_adr = m_axis_dma_write_adr_reg;
assign m_axis_dma_write_tvalid = m_axis_dma_write_tvalid_reg;

// DMA descriptor
always @(posedge clk) begin
    if (rst) begin
        m_axis_dma_write_tvalid_reg <= 1'b0;
    end else begin
        m_axis_dma_write_adr_reg <= m_axis_dma_write_adr_reg;
        m_axis_dma_write_tvalid_reg <= m_axis_dma_write_tvalid_reg;

        if (dma_write_enable_reg && !m_axis_dma_write_tready) begin
            m_axis_dma_write_adr_reg <= dma_write_adr_reg;
            m_axis_dma_write_tvalid_reg <= 1'b1;
        end

        if (m_axis_dma_write_tready) begin
            m_axis_dma_write_tvalid_reg <= 1'b0;
        end
    end
end

endmodule

`resetall
