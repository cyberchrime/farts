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
module axis_append #
(
    parameter DATA_WIDTH = 8,
    parameter KEEP_WIDTH = DATA_WIDTH/8,
    parameter PREPEND_VALUE_WIDTH = 32,
    parameter USER_WIDTH = 1,
    // endianess of the inserted timestamp
    // valid values: "LITTLE" (little endian), "BIG" (big endian)
    parameter LITTLE_ENDIAN = 1
)
(
    input  wire                           clk,
    input  wire                           rst,

    /*
     * AXI4-Stream input
     */
    input  wire [DATA_WIDTH-1:0]          s_axis_tdata,
    input  wire                           s_axis_tvalid,
    input  wire                           s_axis_tlast,
    output wire                           s_axis_tready,
    input  wire [USER_WIDTH-1:0]          s_axis_tuser,
    input  wire [KEEP_WIDTH-1:0]          s_axis_tkeep,


    /*
     * AXI4-Stream output
     */
    output wire [DATA_WIDTH-1:0]          m_axis_tdata,
    output wire                           m_axis_tvalid,
    input  wire                           m_axis_tready,
    output wire                           m_axis_tlast,
    output wire [USER_WIDTH-1:0]          m_axis_tuser,
    output wire [KEEP_WIDTH-1:0]          m_axis_tkeep,

    /*
     * Value to append
     */
    input  wire [PREPEND_VALUE_WIDTH-1:0] post_tdata,
    input  wire [KEEP_WIDTH-1:0]          post_tkeep,

    /*
     * packet start
     */
    input wire                            start_packet
);

localparam PIPELINE_LENGTH = PREPEND_VALUE_WIDTH/DATA_WIDTH;

initial begin
    if ((PREPEND_VALUE_WIDTH % DATA_WIDTH) > 0) begin
        $error("Error: PREPEND_VALUE_WIDTH must be a multiple of DATA_WIDTH!");
        $finish;
    end
end



reg [DATA_WIDTH-1:0] data_regs[PIPELINE_LENGTH-1:0];
reg valid_regs [PIPELINE_LENGTH-1:0];
reg last_regs [PIPELINE_LENGTH-1:0];
reg [KEEP_WIDTH-1:0] keep_regs [PIPELINE_LENGTH-1:0];
reg [USER_WIDTH-1:0] user_regs[PIPELINE_LENGTH-1:0];

assign m_axis_tdata = data_regs[PIPELINE_LENGTH-1];
assign m_axis_tvalid = valid_regs[PIPELINE_LENGTH-1];
assign m_axis_tlast = last_regs[PIPELINE_LENGTH-1];
assign m_axis_tuser = user_regs[PIPELINE_LENGTH-1];
assign m_axis_tkeep = keep_regs[PIPELINE_LENGTH-1];

assign s_axis_tready = m_axis_tready;

integer i;

reg start_packet_reg = 1'b0;
reg stall_reg = 1'b0;

always @(posedge clk) begin
    if (rst) begin
        start_packet_reg <= 1'b0;
        stall_reg <= 1'b1;

        for (i = 0; i < PIPELINE_LENGTH; i = i + 1) begin
            data_regs[i] <= {DATA_WIDTH{1'b0}};
            valid_regs[i] <= 1'b0;
            last_regs[i] <= 1'b0;
            user_regs[i] <= {USER_WIDTH{1'b0}};
            keep_regs[i] <= {KEEP_WIDTH{1'b0}};
        end
    end else begin
	    if (m_axis_tready && !stall_reg) begin
		    for (i = 1; i < PIPELINE_LENGTH; i = i + 1) begin
			    data_regs[i] <= data_regs[i-1];
			    valid_regs[i] <= valid_regs[i-1];
			    last_regs[i] <= last_regs[i-1];
			    user_regs[i] <= user_regs[i-1];
			    keep_regs[i] <= keep_regs[i-1];
		    end
		    data_regs[0] <= s_axis_tdata;
		    valid_regs[0] <= s_axis_tvalid;
		    last_regs[0] <= s_axis_tlast;
			user_regs[0] <= s_axis_tuser;
		    keep_regs[0] <= s_axis_tkeep;


		    if (last_regs[PIPELINE_LENGTH-1]) begin
			    valid_regs[PIPELINE_LENGTH-1] <= 1'b0;
			    stall_reg <= 1'b1;
		    end
	    end else if (stall_reg) begin
		    valid_regs[PIPELINE_LENGTH-1] <= 1'b0;
	    end
    end
end


endmodule

`resetall
