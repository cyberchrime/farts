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
module phy_bridge #
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
    parameter CLOCK_INPUT_STYLE = "BUFG",
    // Use 90 degree clock for RGMII transmit ("TRUE", "FALSE")
    parameter USE_CLK90 = "TRUE",
    // Use a register stage for bridging the PHY's
    parameter REGISTER_STAGE = "FALSE"
)
(
    /*
     * Ethernet PORT 1: 1000BASE-T RGMII
     */
    input  wire       phy1_rgmii_rx_clk,
    input  wire [3:0] phy1_rgmii_rxd,
    input  wire       phy1_rgmii_rx_ctl,
    output wire       phy1_rgmii_tx_clk,
    output wire [3:0] phy1_rgmii_txd,
    output wire       phy1_rgmii_tx_ctl,

    /*
     * Ethernet PORT 2: 1000BASE-T RGMII
     */
    input  wire       phy2_rgmii_rx_clk,
    input  wire [3:0] phy2_rgmii_rxd,
    input  wire       phy2_rgmii_rx_ctl,
    output wire       phy2_rgmii_tx_clk,
    output wire [3:0] phy2_rgmii_txd,
    output wire       phy2_rgmii_tx_ctl
);

if (REGISTER_STAGE == "TRUE") begin
    wire phy1_gmii_rx_clk;
    wire [7:0] phy1_gmii_rxd;
    wire phy1_rgmii_rx_ctl_1;
    wire phy1_rgmii_rx_ctl_2;

    wire phy2_gmii_rx_clk;
    wire [7:0] phy2_gmii_rxd;
    wire phy2_rgmii_rx_ctl_1;
    wire phy2_rgmii_rx_ctl_2;


    oddr #(
        .TARGET(TARGET),
        .IODDR_STYLE(IODDR_STYLE),
        .WIDTH(5)
    )
    phy2_data_oddr_inst (
        .clk(phy2_tx_clk),
        .d1({phy1_gmii_rxd[3:0], phy1_rgmii_rx_ctl_1}),
        .d2({phy1_gmii_rxd[7:4], phy1_rgmii_rx_ctl_2}),
        .q({phy2_rgmii_txd, phy2_rgmii_tx_ctl})
    );

    wire phy2_tx_clk;
    assign phy2_rgmii_tx_clk = phy2_tx_clk;

    ssio_ddr_in #
    (
        .TARGET(TARGET),
        .CLOCK_INPUT_STYLE(CLOCK_INPUT_STYLE),
        .IODDR_STYLE(IODDR_STYLE),
        .WIDTH(5)
    )
    phy1_data_iddr_inst (
        .input_clk(phy1_rgmii_rx_clk),
        .input_d({phy1_rgmii_rxd, phy1_rgmii_rx_ctl}),
        .output_clk(phy2_tx_clk),
        .output_q1({phy1_gmii_rxd[3:0], phy1_rgmii_rx_ctl_1}),
        .output_q2({phy1_gmii_rxd[7:4], phy1_rgmii_rx_ctl_2})
    );


    oddr #(
        .TARGET(TARGET),
        .IODDR_STYLE(IODDR_STYLE),
        .WIDTH(5)
    )
    phy1_data_oddr_inst (
        .clk(phy1_tx_clk),
        .d1({phy2_gmii_rxd[3:0], phy2_rgmii_rx_ctl_1}),
        .d2({phy2_gmii_rxd[7:4], phy2_rgmii_rx_ctl_2}),
        .q({phy1_rgmii_txd, phy1_rgmii_tx_ctl})
    );

    wire phy1_tx_clk;
    assign phy1_rgmii_tx_clk = phy1_tx_clk;

    ssio_ddr_in #
    (
        .TARGET(TARGET),
        .CLOCK_INPUT_STYLE(CLOCK_INPUT_STYLE),
        .IODDR_STYLE(IODDR_STYLE),
        .WIDTH(5)
    )
    phy2_data_iddr_inst (
        .input_clk(phy2_rgmii_rx_clk),
        .input_d({phy2_rgmii_rxd, phy2_rgmii_rx_ctl}),
        .output_clk(phy1_tx_clk),
        .output_q1({phy2_gmii_rxd[3:0], phy2_rgmii_rx_ctl_1}),
        .output_q2({phy2_gmii_rxd[7:4], phy2_rgmii_rx_ctl_2})
    );
end else begin
    assign phy1_rgmii_tx_clk = phy2_rgmii_rx_clk;
    assign phy1_rgmii_txd = phy2_rgmii_rxd;
    assign phy1_rgmii_tx_ctl = phy2_rgmii_rx_ctl;

    assign phy2_rgmii_tx_clk = phy1_rgmii_rx_clk;
    assign phy2_rgmii_txd = phy1_rgmii_rxd;
    assign phy2_rgmii_tx_ctl = phy1_rgmii_rx_ctl;
end


endmodule

`resetall
