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
 * PHY Interface. TX input is expected to be from another PHY interface
 */
module rgmii_phy_bridge_if #
(
    // target ("SIM", "GENERIC", "XILINX", "ALTERA")
    parameter TARGET = "GENERIC",
    // IODDR style ("IODDR", "IODDR2")
    // Use IODDR for Virtex-4, Virtex-5, Virtex-6, 7 Series, Ultrascale
    // Use IODDR2 for Spartan-6
    parameter IODDR_STYLE = "IODDR2",
    // Clock input style ("BUFG", "BUFR", "BUFIO", "BUFIO2")
    // Use BUFR for Virtex-6, 7-series
    // Use BUFG for Virtex-5, Spartan-6, Ultrascale
    parameter CLOCK_INPUT_STYLE = "BUFG"
)
(
    input  wire        rst,
    /*
     * RGMII interface to PHY
     */
    input  wire        phy_rgmii_rx_clk,
    input  wire [3:0]  phy_rgmii_rxd,
    input  wire        phy_rgmii_rx_ctl,
    output wire        phy_rgmii_tx_clk,
    output wire [3:0]  phy_rgmii_txd,
    output wire        phy_rgmii_tx_ctl,

    /*
     * GMII interface from other PHY RGMII interface
     */
    input  wire        gmii_tx_clk,
    input  wire [7:0]  gmii_txd,
    input  wire        gmii_tx_en,
    input  wire        gmii_tx_er,

    /*
     * GMII interface to MAC and other PHY RGMII interface
     */
    output wire        gmii_rx_clk,
    output wire        gmii_rx_rst,
    output wire [7:0]  gmii_rxd,
    output wire        gmii_rx_dv,
    output wire        gmii_rx_er
);

wire gmii_rx_clk_int;

assign gmii_rx_clk = gmii_rx_clk_int;
assign phy_rgmii_tx_clk = gmii_tx_clk;



oddr #(
    .TARGET(TARGET),
    .IODDR_STYLE(IODDR_STYLE),
    .WIDTH(5)
)
oddr_inst (
    .clk(gmii_tx_clk),
    .d1({gmii_txd[3:0], gmii_tx_en}),
    .d2({gmii_txd[7:4], gmii_tx_er}),
    .q({phy_rgmii_txd, phy_rgmii_tx_ctl})
);

ssio_ddr_in #
(
    .TARGET(TARGET),
    .CLOCK_INPUT_STYLE(CLOCK_INPUT_STYLE),
    .IODDR_STYLE(IODDR_STYLE),
    .WIDTH(5)
)
iddr_inst (
    .input_clk(phy_rgmii_rx_clk),
    .input_d({phy_rgmii_rxd, phy_rgmii_rx_ctl}),
    .output_clk(gmii_rx_clk_int),
    .output_q1({gmii_rxd[3:0], gmii_tx_en}),
    .output_q2({gmii_rxd[7:4], gmii_rx_er})
);


reg [3:0] rx_rst_reg = 4'hf;
assign gmii_rx_rst = rx_rst_reg[0];

always @(posedge gmii_rx_clk_int or posedge rst) begin
    if (rst) begin
        rx_rst_reg <= 4'hf;
    end else begin
        rx_rst_reg <= {1'b0, rx_rst_reg[3:1]};
    end
end


endmodule

`resetall
