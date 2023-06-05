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
 * AXI4-Stream Padder to arbitrary boundary with pseudo-random data
 */
module axis_padder #
(
    parameter DATA_WIDTH = 8,
    parameter KEEP_WIDTH = DATA_WIDTH/8,
    parameter USER_WIDTH = 1,
    parameter ALIGN = 2,
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
);


assign m_axis_tdata = axis_tdata;
assign m_axis_tvalid = axis_tvalid;
assign s_axis_tready = axis_tready;
assign m_axis_tlast = axis_tlast;
assign m_axis_tuser = axis_tuser;
assign m_axis_tkeep = axis_tkeep;


reg [DATA_WIDTH-1:0] axis_tdata_reg = 0;
reg axis_tvalid_reg = 0;
reg axis_tlast_reg = 0;
reg axis_tready_reg = 0;
reg [USER_WIDTH-1:0] axis_tuser_reg = 0;
reg [KEEP_WIDTH-1:0] axis_tkeep_reg = 0;

reg tlast_reg = 0;
reg [ALIGN-1:0] cnt_reg = 0;

always @(posedge clk) begin
    if (rst) begin
		cnt_reg <= 0;
		axis_tvalid_reg <= 1'b0;
		axis_tready_reg <= 1'b0;
    end else begin
		axis_tvalid_reg <= 1'b0;
		axis_tready_reg <= 1'b0;
		m_axis_tlast_reg <= 1'b0;

		if (s_axis_tvalid == 1 && m_axis_tready) begin
			cnt_reg <= cnt_reg + 1;

			axis_tvalid_reg <= 1'b1;
			axis_tready_reg <= 1'b1;
			axis_tuser_reg <= s_axis_tuser;
			axis_tkeep_reg <= s_axis_tkeep;
			axis_tdata_reg <= s_axis_tdata;
			

			if (m_axis_tlast == 1) begin
				if (cnt_reg == 0) begin
					axis_tlast_reg <= 1'b1; 
				else
					tlast_reg <= 1'b1;
				end
			end
		end
		
		if (m_axis_tready && tlast_reg == 1'b1) begin
			cnt_reg <= cnt_reg + 1;

			axis_tready_reg <= 1'b0;
			axis_tvalid_reg <= 1'b1;

			if (cnt_reg == 0) begin
				tlast_reg <= 1'b0;

				axis_tlast_reg <= 1'b1;
				axis_tvalid_reg <= 1'b1;
				axis_tkeep_reg <= {KEEP_WIDTH{1'b1}};
			end
		end
    end
end


endmodule

`resetall
