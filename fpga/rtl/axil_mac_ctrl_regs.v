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
 * Register for MAC control, accessible with AXI4 lite
 */
module axil_mac_ctrl_regs #
(
    // Width of AXI Lite data interface in bits
    parameter AXIL_DATA_WIDTH = 32,
    // Width of AXI Lite address in bits
    parameter AXIL_ADDR_WIDTH = 8,
    // Width of AXI Lite strobe (width of data bus in words)
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
    input  wire [AXIL_ADDR_WIDTH-1:0] s_axil_awaddr,
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
     * Status counters
     */
    input  wire                       mac1_start_frame,
    input  wire                       mac1_bad_frame,
    input  wire                       mac1_bad_fcs,
    input  wire                       fifo1_bad_frame,
    input  wire                       fifo1_good_frame,
    input  wire                       fifo1_overflow,

    input  wire                       mac2_start_frame,
    input  wire                       mac2_bad_frame,
    input  wire                       mac2_bad_fcs,
    input  wire                       fifo2_bad_frame,
    input  wire                       fifo2_good_frame,
    input  wire                       fifo2_overflow,

    /*
     * Status input
     */
    input  wire                       status_buffers_empty,
    input  wire                       status_busy,

    /*
     * Control output
     */
    output wire                       ctrl_enable,
    output wire                       ctrl_mii_select
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

assign ctrl_enable = enable_reg;
assign ctrl_mii_select = mii_select_reg;

localparam [AXIL_ADDR_WIDTH-1:0]
    MAC_CONTROL_ID = 8'h00,
    MAC_STATUS_ID = 8'h04,

    MAC1_START_FRAME_ID = 8'h40,
    MAC1_BAD_FRAME = 8'h44,
    MAC1_BAD_FCS = 8'h48,
    FIFO1_BAD_FRAME = 8'h4c,
    FIFO1_GOOD_FRAME = 8'h50,
    FIFO1_OVERFLOW = 8'h54,

    MAC2_START_FRAME_ID = 8'h60,
    MAC2_BAD_FRAME = 8'h64,
    MAC2_BAD_FCS = 8'h68,
    FIFO2_BAD_FRAME = 8'h6c,
    FIFO2_GOOD_FRAME = 8'h70,
    FIFO2_OVERFLOW = 8'h74;

reg mii_select_reg = 1'b0;
reg enable_reg = 1'b0;
reg soft_reset_reg = 1'b0;

reg [31:0] mac1_start_frame_reg, mac2_start_frame_reg;
reg [31:0] mac1_bad_frame_reg, mac2_bad_frame_reg;
reg [31:0] mac1_bad_fcs_reg, mac2_bad_fcs_reg;
reg [31:0] fifo1_bad_frame_reg, fifo2_bad_frame_reg;
reg [31:0] fifo1_good_frame_reg, fifo2_good_frame_reg;
reg [31:0] fifo1_overflow_reg, fifo2_overflow_reg;

// TODO: explain simultanious RW behavior

// WRITE
always @(posedge clk) begin
    wready_reg <= wready_reg;
    bvalid_reg <= bvalid_reg;

    mii_select_reg <= mii_select_reg;
    soft_reset_reg <= 1'b0;

    if (rst) begin
        bvalid_reg <= 1'b0;
        enable_reg <= 1'b0;
        mii_select_reg <= 1'b0;

        mac1_start_frame_reg <= 32'b0;
        mac1_bad_frame_reg <= 32'b0;
        mac1_bad_fcs_reg <= 32'b0;
        fifo1_bad_frame_reg <= 32'b0;
        fifo1_good_frame_reg <= 32'b0;
        fifo1_overflow_reg <= 32'b0;

        mac2_start_frame_reg <= 32'b0;
        mac2_bad_frame_reg <= 32'b0;
        mac2_bad_fcs_reg <= 32'b0;
        fifo2_bad_frame_reg <= 32'b0;
        fifo2_good_frame_reg <= 32'b0;
        fifo2_overflow_reg <= 32'b0;
    end else begin
        // update status signals
        if (soft_reset_reg) begin
            mac1_start_frame_reg <= 32'b0;
            mac1_bad_frame_reg <= 32'b0;
            mac1_bad_fcs_reg <= 32'b0;
            fifo1_bad_frame_reg <= 32'b0;
            fifo1_good_frame_reg <= 32'b0;
            fifo1_overflow_reg <= 32'b0;

            mac2_start_frame_reg <= 32'b0;
            mac2_bad_frame_reg <= 32'b0;
            mac2_bad_fcs_reg <= 32'b0;
            fifo2_bad_frame_reg <= 32'b0;
            fifo2_good_frame_reg <= 32'b0;
            fifo2_overflow_reg <= 32'b0;
        end else begin
            mac1_start_frame_reg <= mac1_start_frame_reg + mac1_start_frame;
            mac1_bad_frame_reg <= mac1_bad_frame_reg + mac1_bad_frame;
            mac1_bad_fcs_reg <= mac1_bad_fcs_reg + mac1_bad_fcs;
            fifo1_bad_frame_reg <= fifo1_bad_frame_reg + fifo1_bad_frame;
            fifo1_good_frame_reg <= fifo1_good_frame_reg + fifo1_good_frame;
            fifo1_overflow_reg <= fifo1_overflow_reg + fifo1_overflow;

            mac2_start_frame_reg <= mac2_start_frame_reg + mac2_start_frame;
            mac2_bad_frame_reg <= mac2_bad_frame_reg + mac2_bad_frame;
            mac2_bad_fcs_reg <= mac2_bad_fcs_reg + mac2_bad_fcs;
            fifo2_bad_frame_reg <= fifo2_bad_frame_reg + fifo2_bad_frame;
            fifo2_good_frame_reg <= fifo2_good_frame_reg + fifo2_good_frame;
            fifo2_overflow_reg <= fifo2_overflow_reg + fifo2_overflow;
        end

        if (s_axil_wvalid && s_axil_awvalid && s_axil_bready && !wready_reg && !bvalid_reg) begin
            wready_reg <= 1'b1;

            case (s_axil_awaddr)
                MAC_CONTROL_ID: begin
                    enable_reg <= s_axil_wdata[0];
                    mii_select_reg <= s_axil_wdata[1];
                    soft_reset_reg <= s_axil_wdata[2];
                    bresp_reg <= 2'b00;
                end
                MAC_STATUS_ID: begin
                    bresp_reg <= 2'b00;
                end
                MAC1_START_FRAME_ID: begin
                    mac1_start_frame_reg <= s_axil_wdata;
                    bresp_reg <= 2'b00;
                end
                MAC1_BAD_FRAME: begin
                    mac1_bad_frame_reg <= s_axil_wdata;
                    bresp_reg <= 2'b00;
                end
                MAC1_BAD_FCS: begin
                    mac1_bad_fcs_reg <= s_axil_wdata;
                    bresp_reg <= 2'b00;
                end
                FIFO1_BAD_FRAME: begin
                    fifo1_bad_frame_reg <= s_axil_wdata;
                    bresp_reg <= 2'b00;
                end
                FIFO1_GOOD_FRAME: begin
                    fifo1_good_frame_reg <= s_axil_wdata;
                    bresp_reg <= 2'b00;
                end
                FIFO1_OVERFLOW: begin
                    fifo1_overflow_reg <= s_axil_wdata;
                    bresp_reg <= 2'b00;
                end
                MAC2_START_FRAME_ID: begin
                    mac2_start_frame_reg <= s_axil_wdata;
                    bresp_reg <= 2'b00;
                end
                MAC2_BAD_FRAME: begin
                    mac2_bad_frame_reg <= s_axil_wdata;
                    bresp_reg <= 2'b00;
                end
                MAC2_BAD_FCS: begin
                    mac2_bad_fcs_reg <= s_axil_wdata;
                    bresp_reg <= 2'b00;
                end
                FIFO2_BAD_FRAME: begin
                    fifo2_bad_frame_reg <= s_axil_wdata;
                    bresp_reg <= 2'b00;
                end
                FIFO2_GOOD_FRAME: begin
                    fifo2_good_frame_reg <= s_axil_wdata;
                    bresp_reg <= 2'b00;
                end
                FIFO2_OVERFLOW: begin
                    fifo2_overflow_reg <= s_axil_wdata;
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
end


reg [1:0] rresp_reg = 2'b0;
reg rvalid_reg = 1'b0;
reg arready_reg = 1'b0;
reg [AXIL_DATA_WIDTH-1:0] rdata_reg = {AXIL_DATA_WIDTH{1'b0}};

reg busy_reg = 1'b0;
reg buffers_empty_reg = 1'b0;

// READ
always @(posedge clk) begin
    rvalid_reg <= 1'b0;
    rdata_reg <= rdata_reg;
    rresp_reg <= rresp_reg;
    arready_reg <= arready_reg;

    busy_reg <= status_busy;
    buffers_empty_reg <= status_buffers_empty;

    if (s_axil_arvalid && s_axil_rready && !rvalid_reg) begin
        rvalid_reg <= 1'b1;
        arready_reg <= 1'b1;

        case (s_axil_araddr)
            MAC_CONTROL_ID: begin
                rdata_reg <= {30'b0, mii_select_reg, enable_reg};
                rresp_reg <= 2'b00;
            end
            MAC_STATUS_ID: begin
                rdata_reg <= {30'b0, buffers_empty_reg, busy_reg};
                rresp_reg <= 2'b00;
            end
            MAC1_START_FRAME_ID: begin
                rdata_reg <= mac1_start_frame_reg;
                rresp_reg <= 2'b00;
            end
            MAC1_BAD_FRAME: begin
                rdata_reg <= mac1_bad_frame_reg;
                rresp_reg <= 2'b00;
            end
            MAC1_BAD_FCS: begin
                rdata_reg <= mac1_bad_fcs_reg;
                rresp_reg <= 2'b00;
            end
            FIFO1_BAD_FRAME: begin
                rdata_reg <= fifo1_bad_frame_reg;
                rresp_reg <= 2'b00;
            end
            FIFO1_GOOD_FRAME: begin
                rdata_reg <= fifo1_good_frame_reg;
                rresp_reg <= 2'b00;
            end
            FIFO1_OVERFLOW: begin
                rdata_reg <= fifo1_overflow_reg;
                rresp_reg <= 2'b00;
            end
            MAC2_START_FRAME_ID: begin
                rdata_reg <= mac2_start_frame_reg;
                rresp_reg <= 2'b00;
            end
            MAC2_BAD_FRAME: begin
                rdata_reg <= mac2_bad_frame_reg;
                rresp_reg <= 2'b00;
            end
            MAC2_BAD_FCS: begin
                rdata_reg <= mac2_bad_fcs_reg;
                rresp_reg <= 2'b00;
            end
            FIFO2_BAD_FRAME: begin
                rdata_reg <= fifo2_bad_frame_reg;
                rresp_reg <= 2'b00;
            end
            FIFO2_GOOD_FRAME: begin
                rdata_reg <= fifo2_good_frame_reg;
                rresp_reg <= 2'b00;
            end
            FIFO2_OVERFLOW: begin
                rdata_reg <= fifo2_overflow_reg;
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
