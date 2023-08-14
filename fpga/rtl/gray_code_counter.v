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
 * Native Gray Code Counter
 */
module gray_code_counter #
(
    parameter WIDTH = 32,
    parameter RESET_VALUE = 32'b010001110001100000
)
(
    input  wire clk,
    input  wire rst,
    input  wire enable,

    output wire carry,
    output wire [WIDTH-1:0] cnt
);

reg [WIDTH:0] gray_cnt_reg = 0, gray_cnt_next;
reg [WIDTH:0] ones_below;
reg carry_reg = 0, carry_next;

initial begin
    if (WIDTH < 2) begin
        $error("Error: WIDTH must be at least 2 (instance %m)");
        $finish;
    end
end

assign cnt = gray_cnt_reg[WIDTH:1];

integer i;


always @(*) begin
    gray_cnt_next = gray_cnt_reg;

    if (enable) begin
        if (gray_cnt_reg[WIDTH:1] == RESET_VALUE) begin
            gray_cnt_next[WIDTH:1] = {WIDTH{1'b0}};
            gray_cnt_next[0] = 1'b1;
        
        end else begin
            gray_cnt_next[0] = !gray_cnt_reg[0];

            ones_below[0] = 1'b0;
            for (i = 0; i < WIDTH; i = i + 1) begin
                ones_below[i+1] = gray_cnt_reg[i] || ones_below[i];
            end

            for (i = 1; i < WIDTH; i = i + 1) begin
                if (gray_cnt_reg[i-1] && !ones_below[i-1]) begin
                    gray_cnt_next[i] = !gray_cnt_reg[i];
                end
            end
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        gray_cnt_reg[WIDTH:1] <= {WIDTH{1'b0}};
        gray_cnt_reg[0] <= 1'b1;
    end else begin
        if (enable) begin
            gray_cnt_reg <= gray_cnt_next;
        end else begin
            gray_cnt_reg <= gray_cnt_reg;
        end
    end
end


endmodule

`resetall
