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
 * PCAP Timestamp generator with nanosecond precision; works only for
 * if PERIOD*k=1.000.000.000
 */
module pcap_clock #
(
    parameter CLOCK_PERIOD = 4
)
(
    input  wire        clk,
    input  wire        rst,

    output wire [31:0] nsec,
    output wire [31:0] sec
);

localparam LIMIT = 1_000_000_000 - CLOCK_PERIOD;

reg [29:0] nsec_reg = 30'b0;
reg [31:0] sec_reg = 32'b0;

wire [29:0] nsec_incr = nsec_reg + CLOCK_PERIOD;

assign nsec = {2'b0, nsec_reg};
assign sec = sec_reg;

always @(posedge clk) begin
    if (rst) begin
        nsec_reg <= 30'b0;
        sec_reg <= 32'b0;
    end else begin
        if (nsec_reg == LIMIT) begin
            nsec_reg <= 30'd0;
            sec_reg <= sec_reg + 32'd1;
        end else begin
            nsec_reg <= nsec_incr;
            sec_reg <= sec_reg;
        end
    end
end


endmodule

`resetall
