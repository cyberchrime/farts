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
 * AXI Stream to DMA Descriptor and vice versa converter
 */
module dma_desc_regs #
(
    // Width of AXI Address interface in bits
    parameter AXI_ADDR_WIDTH = 32,
    // Width of AXI stream interfaces in bits
    parameter AXIS_DATA_WIDTH = 64,
    // Width of data packets
    parameter LEN_WIDTH = 16,
    // Number of words in the DMA descriptor
    parameter DESC_WORDS = 2,
    // Length of a word in the DMA descriptor
    parameter DESC_WORD_WIDTH = 64
)
(
    input  wire                       clk,
    input  wire                       rst,

    /*
     * Input data
     */
    input  wire [AXIS_DATA_WIDTH-1:0] data_in,
    input  wire                       data_in_valid,

    /*
     * Output data
     */
    output wire [AXIS_DATA_WIDTH-1:0] data_out,

    /*
     * Descriptor output
     */
    output wire [AXI_ADDR_WIDTH-1:0]  dma_desc_addr,
    output wire [LEN_WIDTH-1:0]       dma_desc_length,
    output wire                       dma_desc_empty,

    /*
     * AXI4-Stream Slave Interface for modifying the descriptor
     */
    input  wire [LEN_WIDTH-1:0]       s_axis_dma_desc_length,
    input  wire                       s_axis_dma_desc_valid
);

localparam MAX_AXI_ADDR_WIDTH = 64;
localparam PIPELINE_WIDTH = AXIS_DATA_WIDTH;
localparam PIPELINE_LENGTH = (DESC_WORD_WIDTH * DESC_WORDS) / PIPELINE_WIDTH;

localparam COUNTER_WIDTH = $clog2(PIPELINE_LENGTH);

integer i;


reg [127:0] regs;

assign data_out = regs;
assign dma_desc_addr = regs[AXI_ADDR_WIDTH-1:0];
assign dma_desc_length = regs[95:64];
assign dma_desc_empty = regs[96];

always @(posedge clk) begin
    if (data_in_valid) begin
        regs <= data_in;
    end

    if (s_axis_dma_desc_valid) begin
        regs[96] <= 1'b0; // Not empty anymore
        regs[95:64] <= {
            {(32-LEN_WIDTH){1'b0}},
            s_axis_dma_desc_length
        };
    end
end

endmodule

`resetall
