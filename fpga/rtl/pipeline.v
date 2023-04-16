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
 * RGMII Stream to PCAP Stream converter
 */
module pipeline #
(
    // Length of pipeline (minimum: 1)
    parameter DEPTH = 2,
    // Width of data
    parameter DATA_WIDTH = 16
)(
    input  wire                  clk,
    input  wire                  rst,

    input  wire [DATA_WIDTH-1:0] data_in,
    output wire [DATA_WIDTH-1:0] data_out
);

initial begin
    if (DEPTH < 1) begin
        $error("Error: DEPTH must be at least 1 (instance %m)");
        $finish;
    end
end


assign data_out = pipeline[DEPTH-1];


reg [DATA_WIDTH-1:0] pipeline[DEPTH-1:0];

integer i;
always @(posedge clk) begin
    if (rst) begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            pipeline[i] <= {DATA_WIDTH{1'b0}};
        end
    end else begin
        for (i = 1; i < DEPTH; i = i + 1) begin
            pipeline[i] <= pipeline[i-1];
        end

        pipeline[0] <= data_in;
    end
end

endmodule

`resetall
