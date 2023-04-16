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
`ifndef FORMAL
`resetall
`endif
`timescale 1ns / 1ps
`default_nettype none

/*
 * Simple FIFO
 */
module simple_fifo #
(
    parameter DATA_WIDTH = 16,
    // memory size; must be a power of 2
    parameter DEPTH = 16,
    // 0 ignores the ready signal, 1 requires it
    parameter USE_READY = 0
)
(
    input  wire                  clk,
    input  wire                  rst,

    input  wire [DATA_WIDTH-1:0] input_data,
    input  wire                  input_valid,
    output wire                  input_ready,

    output wire [DATA_WIDTH-1:0] output_data,
    input  wire                  output_ready,
    output wire                  output_valid
);


initial begin
    if (USE_READY < 0 || USE_READY > 1) begin
        $error("Error: Illegal value for parameter USE_READY (instance %m)");
        $finish;
    end
end


localparam POS_WIDTH = $clog2(DEPTH);

reg [POS_WIDTH-1:0] rd_pos = {POS_WIDTH{1'b0}};
reg [POS_WIDTH-1:0] wr_pos = {POS_WIDTH{1'b0}};
wire [POS_WIDTH-1:0] rd_pos_inc = rd_pos + 1;

reg [DATA_WIDTH-1:0] mem[DEPTH:0];

reg empty_reg = 1'b1;
wire full = !empty_reg && (rd_pos == wr_pos);

reg output_valid_reg = 1'b0;
assign output_valid = output_valid_reg;
reg input_ready_reg = 1'b0;
assign input_ready = input_ready_reg;

wire input_ready_int = input_ready_reg || !USE_READY;
wire write = input_ready_reg || !USE_READY;

reg [DATA_WIDTH-1:0] output_data_reg = {DATA_WIDTH{1'b0}};
assign output_data = output_data_reg;


always @(posedge clk) begin
    if (rst) begin
        rd_pos <= {POS_WIDTH{1'b0}};
        wr_pos <= {POS_WIDTH{1'b0}};

        output_valid_reg <= 1'b0;
        input_ready_reg <= 1'b0;

        empty_reg <= 1'b1;
    end else begin
        rd_pos <= rd_pos;
        wr_pos <= wr_pos;

        if (input_ready_int) begin
            if (input_valid && !full) begin
                mem[wr_pos] <= input_data;
                wr_pos <= wr_pos + 'd1;
                input_ready_reg <= 1'b0;
                empty_reg <= 1'b0;
            end else begin
                input_ready_reg <= !full;
            end
        end

        if (!empty_reg) begin
            output_valid_reg <= 1'b1;
            output_data_reg <= mem[rd_pos];
        end

        if (output_valid_reg && output_ready) begin
            rd_pos <= rd_pos_inc;
            output_valid_reg <= 1'b0;

            if ((rd_pos_inc == wr_pos) && !(input_valid && input_ready_int)) begin
                empty_reg <= 1'b1;
            end
        end
    end
end


`ifdef FORMAL
    always @(posedge clk) begin
        if (empty_reg) begin
            assert (rd_pos == wr_pos);
        end

        //assert (($past(rd_pos) == wr_pos) && (rd_pos > wr_pos));
    end
`endif

endmodule

`resetall
