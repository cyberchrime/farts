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
 * Simple clock domain crossing synchronizer (NO handshake)
 */
module word_cdc #
(
    parameter DATA_WIDTH = 32,
    parameter DEPTH = 2
)
(
    input  wire        input_clk,
    input  wire        output_clk,
    input  wire        rst,

    input  wire [DATA_WIDTH-1:0] input_data,
    output wire [DATA_WIDTH-1:0] output_data
);

reg [DATA_WIDTH-1:0] input_reg, sync_reg[DEPTH-1:0];

initial begin
    if (DEPTH < 2) begin
        $error("Error: Synchronizer depth must be at least 2 (instance %m)");
        $finish;
    end
end

assign output_data = sync_reg[DEPTH-1];

integer i;

// input pipeline
always @(posedge input_clk) begin
    if (rst) begin
        input_reg <= {DATA_WIDTH{1'b0}};
    end else begin
        input_reg <= input_data;
    end
end


// output pipeline
always @(posedge output_clk) begin
    if (rst) begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            sync_reg[i] <= {DATA_WIDTH{1'b0}};
        end
    end else begin
        sync_reg[0] <= input_reg;
        for (i = 1; i < DEPTH; i = i + 1) begin
            sync_reg[i] <= sync_reg[i-1];
        end
    end
end


endmodule

`resetall
