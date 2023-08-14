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
 * Gray-code to binary converter
 */
module gray2bin #
(
    parameter WIDTH = 32
)
(
    input  wire             clk,
    input  wire             rst,

    input  wire [WIDTH-1:0] gray,
    output wire [WIDTH-1:0] bin
);

reg [WIDTH-1:0] bin_reg = {WIDTH{1'b0}};

assign bin = bin_reg;

integer i;

always @(posedge clk) begin
    if (rst) begin
        bin_reg = {WIDTH{1'b0}};
    end else begin
        for (i = 0; i < WIDTH; i = i + 1) begin
            bin_reg[i] = ^(gray >> i);
        end
    end
end

endmodule

`resetall
