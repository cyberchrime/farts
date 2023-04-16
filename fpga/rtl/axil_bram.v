/*

Copyright (c) 2018 Alex Forencich
Copyright (c) 2023 Chris H. Meyer

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.


This program is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation, either version 3 of the License, or (at your option)
any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
more details.

You should have received a copy of the GNU General Public License along with
this program. If not, see <https://www.gnu.org/licenses/>.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
* AXI4-Lite dual port RAM
    */
module axil_bram #
(
    // Width of data bus in bits
    parameter DATA_WIDTH = 128,
    // Width of address bus in bits
    parameter ADDR_WIDTH = 12,
    // Width of wstrb (width of data bus in words)
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    // Width of BRAM address bus
    parameter BRAM_ADDR_WIDTH = (ADDR_WIDTH - $clog2(STRB_WIDTH)),
    // Extra pipeline register on output
    parameter PIPELINE_OUTPUT = 0
)
(
    input  wire                       clk,
    input  wire                       rst,

    input  wire [ADDR_WIDTH-1:0]      s_axil_awaddr,
    input  wire [2:0]                 s_axil_awprot,
    input  wire                       s_axil_awvalid,
    output wire                       s_axil_awready,
    input  wire [DATA_WIDTH-1:0]      s_axil_wdata,
    input  wire [STRB_WIDTH-1:0]      s_axil_wstrb,
    input  wire                       s_axil_wvalid,
    output wire                       s_axil_wready,
    output wire [1:0]                 s_axil_bresp,
    output wire                       s_axil_bvalid,
    input  wire                       s_axil_bready,
    input  wire [ADDR_WIDTH-1:0]      s_axil_araddr,
    input  wire [2:0]                 s_axil_arprot,
    input  wire                       s_axil_arvalid,
    output wire                       s_axil_arready,
    output wire [DATA_WIDTH-1:0]      s_axil_rdata,
    output wire [1:0]                 s_axil_rresp,
    output wire                       s_axil_rvalid,
    input  wire                       s_axil_rready,

    input  wire                       bram_en,
    input  wire                       bram_we,
    input  wire [BRAM_ADDR_WIDTH-1:0] bram_addr,
    input  wire [DATA_WIDTH-1:0]      bram_di,
    output wire [DATA_WIDTH-1:0]      bram_do
);

parameter WORD_WIDTH = STRB_WIDTH;
parameter WORD_SIZE = DATA_WIDTH/WORD_WIDTH;

reg read_eligible;
reg write_eligible;

reg mem_wr_en;
reg mem_rd_en;
reg [BRAM_ADDR_WIDTH-1:0] mem_addr;

reg last_read_reg = 1'b0, last_read_next;

reg s_axil_awready_reg = 1'b0, s_axil_awready_next;
reg s_axil_wready_reg = 1'b0, s_axil_wready_next;
reg s_axil_bvalid_reg = 1'b0, s_axil_bvalid_next;
reg s_axil_arready_reg = 1'b0, s_axil_arready_next;
reg [DATA_WIDTH-1:0] s_axil_rdata_reg = {DATA_WIDTH{1'b0}}, s_axil_rdata_next;
reg s_axil_rvalid_reg = 1'b0, s_axil_rvalid_next;
reg [DATA_WIDTH-1:0] s_axil_rdata_pipe_reg = {DATA_WIDTH{1'b0}};
reg s_axil_rvalid_pipe_reg = 1'b0;

// (* RAM_STYLE="BLOCK" *)
reg [DATA_WIDTH-1:0] mem[(2**BRAM_ADDR_WIDTH)-1:0];

wire [BRAM_ADDR_WIDTH-1:0] s_axil_awaddr_valid = s_axil_awaddr >> (ADDR_WIDTH - BRAM_ADDR_WIDTH);
wire [BRAM_ADDR_WIDTH-1:0] s_axil_araddr_valid = s_axil_araddr >> (ADDR_WIDTH - BRAM_ADDR_WIDTH);

assign s_axil_awready = s_axil_awready_reg;
assign s_axil_wready = s_axil_wready_reg;
assign s_axil_bresp = 2'b00;
assign s_axil_bvalid = s_axil_bvalid_reg;
assign s_axil_arready = s_axil_arready_reg;
assign s_axil_rdata = PIPELINE_OUTPUT ? s_axil_rdata_pipe_reg : s_axil_rdata_reg;
assign s_axil_rresp = 2'b00;
assign s_axil_rvalid = PIPELINE_OUTPUT ? s_axil_rvalid_pipe_reg : s_axil_rvalid_reg;

integer i, j;

initial begin
    // two nested loops for smaller number of iterations per loop
    // workaround for synthesizer complaints about large loop counts
    for (i = 0; i < 2**BRAM_ADDR_WIDTH; i = i + 2**(BRAM_ADDR_WIDTH/2)) begin
        for (j = i; j < i + 2**(BRAM_ADDR_WIDTH/2); j = j + 1) begin
            mem[j] = 0;
        end
    end
end

// ON a simultanious read and write, the write is not acked until the read is done

always @* begin
    mem_wr_en = 1'b0;
    mem_rd_en = 1'b0;

    last_read_next = last_read_reg;

    s_axil_awready_next = 1'b0;
    s_axil_wready_next = 1'b0;
    s_axil_bvalid_next = s_axil_bvalid_reg && !s_axil_bready;

    s_axil_arready_next = 1'b0;
    s_axil_rvalid_next = s_axil_rvalid_reg && !(s_axil_rready || (PIPELINE_OUTPUT && !s_axil_rvalid_pipe_reg));

    write_eligible = s_axil_awvalid && s_axil_wvalid && (!s_axil_bvalid || s_axil_bready) && (!s_axil_awready && !s_axil_wready);
    read_eligible = s_axil_arvalid && (!s_axil_rvalid || s_axil_rready || (PIPELINE_OUTPUT && !s_axil_rvalid_pipe_reg)) && (!s_axil_arready);

    mem_addr = s_axil_araddr_valid;

    if (write_eligible && (!read_eligible || last_read_reg)) begin
        last_read_next = 1'b0;

        s_axil_awready_next = 1'b1;
        s_axil_wready_next = 1'b1;
        s_axil_bvalid_next = 1'b1;

        mem_addr = s_axil_awaddr_valid;
        mem_wr_en = 1'b1;
    end else if (read_eligible) begin
        last_read_next = 1'b1;

        s_axil_arready_next = 1'b1;
        s_axil_rvalid_next = 1'b1;

        mem_rd_en = 1'b1;
    end
end

always @(posedge clk) begin
    last_read_reg <= last_read_next;

    s_axil_awready_reg <= s_axil_awready_next;
    s_axil_wready_reg <= s_axil_wready_next;
    s_axil_bvalid_reg <= s_axil_bvalid_next;

    s_axil_arready_reg <= s_axil_arready_next;
    s_axil_rvalid_reg <= s_axil_rvalid_next;

    if (mem_rd_en) begin
        s_axil_rdata_reg <= mem[mem_addr];
    end else begin
        for (i = 0; i < WORD_WIDTH; i = i + 1) begin
            if (mem_wr_en && s_axil_wstrb[i]) begin
                mem[mem_addr][WORD_SIZE*i +: WORD_SIZE] <= s_axil_wdata[WORD_SIZE*i +: WORD_SIZE];
            end
        end
    end

    if (!s_axil_rvalid_pipe_reg || s_axil_rready) begin
        s_axil_rdata_pipe_reg <= s_axil_rdata_reg;
        s_axil_rvalid_pipe_reg <= s_axil_rvalid_reg;
    end

    if (rst) begin
        last_read_reg <= 1'b0;

        s_axil_awready_reg <= 1'b0;
        s_axil_wready_reg <= 1'b0;
        s_axil_bvalid_reg <= 1'b0;

        s_axil_arready_reg <= 1'b0;
        s_axil_rvalid_reg <= 1'b0;
        s_axil_rvalid_pipe_reg <= 1'b0;
    end
end

reg [DATA_WIDTH-1:0] bram_do_reg = {DATA_WIDTH{1'b0}};
assign bram_do = bram_do_reg;

always @(posedge clk) begin
    if (bram_en) begin
        bram_do_reg <= mem[bram_addr];

        if (bram_we) begin
            for (i = 0; i < WORD_WIDTH; i = i + 1) begin
                mem[bram_addr][WORD_SIZE*i +: WORD_SIZE] <= bram_di[WORD_SIZE*i +: WORD_SIZE];
            end
        end

    end
end

endmodule

`resetall
