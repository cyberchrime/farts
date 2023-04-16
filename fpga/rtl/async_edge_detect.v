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
 * Detect edges of asynchronous signals
 * Implementation of https://www.doulos.com/knowhow/fpga/synchronization-and-edge-detection/
 */
module async_edge_detect
(
    input  wire clk,
    input  wire rst,

    input  wire sig,

    output wire rise,
    output wire fall
);

reg [2:0] sig_reg;

assign rise = !sig_reg[2] && sig_reg[1];
assign fall = sig_reg[2] && !sig_reg[1];

always @(posedge clk) begin
    if (rst) begin
        sig_reg[0] <= 1'b0;
        sig_reg[1] <= 1'b0;
        sig_reg[2] <= 1'b0;
    end else begin
        sig_reg[2] <= sig_reg[1];
        sig_reg[1] <= sig_reg[0];
        sig_reg[0] <= sig;
    end
end


endmodule

`resetall
