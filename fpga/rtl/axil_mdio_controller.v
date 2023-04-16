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
* Controller which sets both PHY's to the same link speed
*/
module axil_mdio_controller #
(
    parameter AXIL_DATA_WIDTH = 32,
    parameter AXIL_ADDR_WIDTH = 12,
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    parameter MDIO_INTERFACES = 2,
    parameter MDIO_CLK_PRESCALE = 8'd26
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
    input  wire [3:0]                 s_axil_wstrb,
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

    output wire [MDIO_INTERFACES-1:0] mdc,
    inout  wire [MDIO_INTERFACES-1:0] mdio
);

axil_mdio_if # (
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .INTERFACES(MDIO_INTERFACES)
)
axil_mdio_if_inst (
    .clk(clk),
    .rst(rst),

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

    .mdio_wdata(mdio_wdata),
    .mdio_op(mdio_op),
    .mdio_reg_adr(mdio_reg_adr),
    .mdio_phy_adr(mdio_phy_adr),
    .mdio_valid(mdio_valid),
    .mdio_ready(mdio_ready),
    .mdio_busy(mdio_busy),

    .mdio_rdata(mdio_rdata),
    .mdio_rdata_ready(mdio_rdata_ready),
    .mdio_rdata_valid(mdio_rdata_valid)
);


wire [(MDIO_INTERFACES*16)-1:0] mdio_wdata;
wire [(MDIO_INTERFACES*2)-1:0] mdio_op;
wire [(MDIO_INTERFACES*5)-1:0] mdio_reg_adr;
wire [(MDIO_INTERFACES*5)-1:0] mdio_phy_adr;
wire [MDIO_INTERFACES-1:0] mdio_valid;
wire [MDIO_INTERFACES-1:0] mdio_ready;
wire [MDIO_INTERFACES-1:0] mdio_busy;

wire [(MDIO_INTERFACES*16)-1:0] mdio_rdata;
wire [MDIO_INTERFACES-1:0] mdio_rdata_ready;
wire [MDIO_INTERFACES-1:0] mdio_rdata_valid;


wire mdio_i[MDIO_INTERFACES-1:0];
wire mdio_o[MDIO_INTERFACES-1:0];
wire mdio_t[MDIO_INTERFACES-1:0];

genvar gi;

generate

    for (gi = 0; gi < MDIO_INTERFACES; gi = gi + 1) begin
        assign mdio_i[gi] = mdio[gi];
        assign mdio[gi] = mdio_t[gi] ? 1'bz : mdio_o[gi];

        mdio_master
        mdio_master_inst (
            .clk(clk),
            .rst(rst),

            /*
            * Host interface
            */
            .cmd_phy_addr(mdio_phy_adr[gi*5 +: 5]),
            .cmd_reg_addr(mdio_reg_adr[gi*5 +: 5]),
            .cmd_data(mdio_wdata[gi*16 +: 16]),
            .cmd_opcode(mdio_op[gi*2 +: 2]),
            .cmd_valid(mdio_valid[gi]),
            .cmd_ready(mdio_ready[gi]),

            .data_out(mdio_rdata[gi*16 +: 16]),
            .data_out_valid(mdio_rdata_valid[gi]),
            .data_out_ready(mdio_rdata_ready[gi]),

            /*
            * MDIO to PHY
            */
            .mdc_o(mdc[gi]),
            .mdio_i(mdio_i[gi]),
            .mdio_o(mdio_o[gi]),
            .mdio_t(mdio_t[gi]),

            /*
            * Status
            */
            .busy(mdio_busy[gi]),

            /*
            * Configuration
            */
            .prescale(MDIO_CLK_PRESCALE)
        );
    end
endgenerate

endmodule

`resetall