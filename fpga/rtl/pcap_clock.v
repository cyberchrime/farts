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
 * PCAP Gray Code Timestamp generator with 8ns precision; 
 * two values:
 * - nanoseconds
 * - and a second
 */
module pcap_clock
(
    input  wire        clk,
    input  wire        rst,

    output wire [31:0] nsec,
    output wire [31:0] sec
);


localparam RESET_VALUE = 32'b00000000000000010001110001100000;

gray_code_counter # (
    .WIDTH(32),
    .RESET_VALUE(RESET_VALUE)
) gray_nsec_inst (
    .clk(clk),
    .rst(rst),
    .enable(1'b1),
    .cnt(nsec)
);

wire sec_en = nsec == RESET_VALUE;

gray_code_counter # (
    .WIDTH(32),
    .RESET_VALUE(32'h80000000) 
) pcap_clk_inst (
    .clk(clk),
    .rst(rst),
    .enable(sec_en),
    .cnt(sec)
);

endmodule

`resetall
