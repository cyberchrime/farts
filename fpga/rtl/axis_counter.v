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
 * AXI4-Stream Timestamp Prepender
 */
module axis_counter #
(
    parameter DATA_WIDTH = 8,
    parameter KEEP_WIDTH = DATA_WIDTH/8,
    parameter USER_WIDTH = 1,
    // input is delayed by a single cycle
    // valid values: 0, 1
    parameter DELAY = 0,
    // endianess of the inserted timestamp
    // valid values: "LITTLE" (little endian), "BIG" (big endian)
    parameter LITTLE_ENDIAN = 1
)
(
    input  wire                           clk,
    input  wire                           rst,

    /*
     * AXI4-Stream output
     */
    output wire [DATA_WIDTH-1:0]          m_axis_tdata,
    output wire                           m_axis_tvalid,
    input  wire                           m_axis_tready,
    output wire                           m_axis_tlast,
    output wire [USER_WIDTH-1:0]          m_axis_tuser,
    output wire [KEEP_WIDTH-1:0]          m_axis_tkeep,

    output wire [10:0]                    axis_dma_desc_write_len_tdata,
    input  wire                           axis_dma_desc_write_len_tready,
    output wire                           axis_dma_desc_write_len_tvalid
);

reg [10:0] len_reg = {11'b0};
reg [10:0] len_counter_reg = {11'b0};
reg axis_dma_desc_write_valid_reg = 1'b0;
reg [7:0] count_reg [KEEP_WIDTH-1:0];

reg [DATA_WIDTH-1:0] m_axis_tdata_reg = {DATA_WIDTH{1'b0}};
reg m_axis_tvalid_reg = 1'b0;
reg m_axis_tlast_reg = 1'b0;

reg axis_dma_desc_write_len_tvalid_reg = 1'b0;


assign m_axis_tdata = m_axis_tdata_reg;
assign m_axis_tvalid = m_axis_tvalid_reg;
assign m_axis_tlast = m_axis_tlast_reg;
assign m_axis_tuser = {USER_WIDTH{1'b0}};
assign m_axis_tkeep = {KEEP_WIDTH{1'b1}};

assign axis_dma_desc_write_len_tdata = len_reg;
assign axis_dma_desc_write_len_tvalid = axis_dma_desc_write_len_tvalid_reg;
integer i;

always @(*) begin
    for (i = 0; i < KEEP_WIDTH; i = i + 1) begin
        m_axis_tdata_reg[i*8 +: 8] <= count_reg[i];
    end
end

always @(posedge clk) begin
    if (rst) begin
        m_axis_tvalid_reg <= 1'b0;
        m_axis_tlast_reg <= 1'b0;
        len_reg <= 11'd64;
        axis_dma_desc_write_len_tvalid_reg <= 1'b1;
        len_counter_reg <= KEEP_WIDTH;

        for (i = 0; i < KEEP_WIDTH; i = i + 1) begin
            count_reg[i] <= i;
        end
    end else begin
        m_axis_tvalid_reg <= 1'b1;

        if (axis_dma_desc_write_len_tready) begin
            axis_dma_desc_write_len_tvalid_reg <= 1'b0;
        end

        if (m_axis_tready) begin
            len_counter_reg <= len_counter_reg + KEEP_WIDTH;
            m_axis_tlast_reg <= 1'b0;

            for (i = 0; i < KEEP_WIDTH; i = i + 1) begin
                count_reg[i] <= count_reg[i] + KEEP_WIDTH;
            end

            if ((len_counter_reg + KEEP_WIDTH) >= len_reg) begin
                m_axis_tlast_reg <= 1'b1;
            end

            if (m_axis_tlast_reg) begin
                if (!m_axis_tready) begin
                    m_axis_tlast_reg <= 1'b1;
                end else begin
                    m_axis_tlast_reg <= 1'b0;
                    len_reg <= len_reg + KEEP_WIDTH;

                    len_counter_reg <= KEEP_WIDTH;
                    for (i = 0; i < KEEP_WIDTH; i = i + 1) begin
                        count_reg[i] <= i;
                    end

                    axis_dma_desc_write_len_tvalid_reg <= 1'b1;
                end
            end

        end
    end
end


endmodule

`resetall
