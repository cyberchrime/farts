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
 * Register for DMA control, accessible with AXI4 lite
 */
module axil_mdio_if #
(
    parameter AXIL_DATA_WIDTH = 32,
    parameter AXIL_ADDR_WIDTH = 12,
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    parameter INTERFACES = 2
)
(
    input  wire                       clk,
    input  wire                       rst,

    /*
     * AXI lite slave interface
     */
    input  wire [AXIL_DATA_WIDTH-1:0] s_axil_awaddr,
    input  wire [2:0]                 s_axil_awprot,
    input  wire                       s_axil_awvalid,
    output wire                       s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0] s_axil_wdata,
    input  wire [AXIL_STRB_WIDTH-1:0] s_axil_wstrb,
    input  wire                       s_axil_wvalid,
    output wire                       s_axil_wready,
    output wire [1:0]                 s_axil_bresp,
    output wire                       s_axil_bvalid,
    input  wire                       s_axil_bready,

    input  wire [AXIL_ADDR_WIDTH-1:0] s_axil_araddr,
    input  wire [2:0]                 s_axil_arprot,
    input  wire                       s_axil_arvalid,
    output wire                       s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0] s_axil_rdata,
    output wire [1:0]                 s_axil_rresp,
    output wire                       s_axil_rvalid,
    input  wire                       s_axil_rready,

    output wire [(INTERFACES*16)-1:0] mdio_wdata,
    output wire [(INTERFACES*2)-1:0]  mdio_op,
    output wire [(INTERFACES*5)-1:0]  mdio_reg_adr,
    output wire [(INTERFACES*5)-1:0]  mdio_phy_adr,
    output wire [INTERFACES-1:0]      mdio_valid,
    input  wire [INTERFACES-1:0]      mdio_ready,
    input  wire [INTERFACES-1:0]      mdio_busy,

    input  wire [(INTERFACES*16)-1:0] mdio_rdata,
    output wire [INTERFACES-1:0]      mdio_rdata_ready,
    input  wire [INTERFACES-1:0]      mdio_rdata_valid
);

integer i;
genvar gi;

initial begin
    if (INTERFACES < 1) begin
        $error("Error: INTERFACES must be bigger than 0 (instance %m)");
        $finish;
    end

    for (i = 0; i < INTERFACES; i = i + 1) begin
        mdio_rdata_reg[i] = 16'b0;
        mdio_wdata_reg[i] = 16'b0;
        mdio_op_reg[i] = 2'b0;
        mdio_reg_adr_reg[i] = 5'b0;
        mdio_phy_adr_reg[i] = 5'b0;
        mdio_start_reg[i] = 1'b0;

        state_reg[i] = IDLE_STATE;
        mdio_valid_reg[i] = 1'b0;
        mdio_rdata_ready_reg[i] = 1'b0;
    end
end

reg [15:0] mdio_rdata_reg[INTERFACES*16-1:0];
reg [15:0] mdio_wdata_reg[INTERFACES*16-1:0];
reg [1:0] mdio_op_reg[INTERFACES*2-1:0];
reg [4:0] mdio_reg_adr_reg[INTERFACES*5-1:0];
reg [4:0] mdio_phy_adr_reg[INTERFACES*5-1:0];
reg mdio_start_reg[INTERFACES*1-1:0];


reg bvalid_reg = 1'b0;
reg [1:0] bresp_reg = 2'b0;
reg wready_reg = 1'b0;

assign s_axil_bvalid = bvalid_reg;
assign s_axil_bresp = bresp_reg;
assign s_axil_awready = wready_reg;
assign s_axil_wready = wready_reg;

assign s_axil_rresp = rresp_reg;
assign s_axil_rvalid = rvalid_reg;
assign s_axil_arready = arready_reg;
assign s_axil_rdata = rdata_reg;



generate
    for (gi = 0; gi < INTERFACES; gi = gi+1) begin
        assign mdio_wdata[gi*16 +: 16] = mdio_wdata_reg[gi];
        assign mdio_op[gi*2 +: 2] = mdio_op_reg[gi];
        assign mdio_reg_adr[gi*5 +: 5] = mdio_reg_adr_reg[gi];
        assign mdio_phy_adr[gi*5 +: 5] = mdio_phy_adr_reg[gi];
        assign mdio_valid[gi] = mdio_valid_reg[gi];
    end
endgenerate

// WRITE
always @(posedge clk)begin
    wready_reg <= wready_reg;
    bvalid_reg <= bvalid_reg;

    for (i = 0; i < INTERFACES; i = i+1) begin
        mdio_wdata_reg[i] <= mdio_wdata_reg[i];
        mdio_op_reg[i] <= mdio_op_reg[i];
        mdio_reg_adr_reg[i] <= mdio_reg_adr_reg[i];
        mdio_phy_adr_reg[i] <= mdio_phy_adr_reg[i];
        mdio_start_reg[i] <= 1'b0;
    end

    if (rst) begin
        for (i = 0; i < INTERFACES; i = i+1) begin
            mdio_wdata_reg[i] <= 16'b0;
            mdio_op_reg[i] <= 2'b0;
            mdio_reg_adr_reg[i] <= 5'b0;
            mdio_phy_adr_reg[i] <= 5'b0;
        end

        bvalid_reg <= 1'b0;
    end else begin
        if (s_axil_wvalid && s_axil_awvalid && s_axil_bready && !wready_reg && !bvalid_reg) begin
            wready_reg <= 1'b1;

            bresp_reg <= 2'b11;

            for (i = 0; i < INTERFACES; i = i+1) begin
                if (s_axil_awaddr == i*4) begin
                    bresp_reg <= 2'b00;

                    mdio_start_reg[i] <= s_axil_wdata[28];
                    mdio_op_reg[i] <= s_axil_wdata[27:26];
                    mdio_phy_adr_reg[i] <= s_axil_wdata[25:21];
                    mdio_reg_adr_reg[i] <= s_axil_wdata[20:16];
                    mdio_wdata_reg[i] <= s_axil_wdata[15:0];
                end
            end
        end else if (wready_reg && s_axil_bready) begin
            wready_reg <= 1'b0;
            bvalid_reg <= 1'b1;
        end else if (bvalid_reg) begin
            bvalid_reg <= 1'b0;
        end
    end
end



reg [1:0] rresp_reg = 2'b0;
reg rvalid_reg = 1'b0;
reg arready_reg = 1'b0;
reg [AXIL_DATA_WIDTH-1:0] rdata_reg = {AXIL_DATA_WIDTH{1'b0}};

// READ
always @(posedge clk) begin
    rvalid_reg <= 1'b0;
    rdata_reg <= rdata_reg;
    rresp_reg <= rresp_reg;
    arready_reg <= arready_reg;

    if (s_axil_arvalid && s_axil_rready && !rvalid_reg) begin
        rvalid_reg <= 1'b1;
        arready_reg <= 1'b1;

        rdata_reg <= {AXIL_DATA_WIDTH{1'b0}};
        rresp_reg <= 2'b11;

        for (i = 0; i < INTERFACES; i = i+1) begin
            if (s_axil_awaddr == i*4) begin
                rdata_reg <= {
                    3'b0,
                    mdio_busy[i],
                    mdio_op_reg[i],
                    mdio_phy_adr_reg[i],
                    mdio_reg_adr_reg[i],
                    mdio_rdata_reg[i]
                };

                rresp_reg <= 2'b00;
            end
        end
    end

    if (rst) begin
        rvalid_reg <= 1'b0;
        arready_reg <= 1'b0;
    end
end


// MDIO Interface
localparam MDIO_READ = 2'b10;
localparam MDIO_WRITE = 2'b01;

localparam IDLE_STATE = 2'd0,
           WAIT_FOR_READY_STATE = 2'd1,
           WAIT_FOR_RDATA_STATE = 2'd2;


reg [1:0] state_reg[INTERFACES-1:0];

reg mdio_valid_reg[INTERFACES-1:0];
reg mdio_rdata_ready_reg[INTERFACES-1:0];

generate
    for (gi = 0; gi < INTERFACES; gi = gi+1) begin
        assign mdio_valid[gi] = mdio_valid_reg[gi];
        assign mdio_rdata_ready[gi] = mdio_rdata_ready_reg[gi];

        always @(posedge clk) begin
            if (rst) begin
                mdio_valid_reg[gi] <= 1'b0;
                mdio_rdata_ready_reg[gi] <= 1'b0;

                state_reg[gi] <= IDLE_STATE;
            end else begin
                mdio_valid_reg[gi] <= mdio_valid_reg[gi];
                mdio_rdata_ready_reg[gi] <= mdio_rdata_ready_reg[gi];

                state_reg[gi] <= state_reg[gi];

                case (state_reg[gi])
                    IDLE_STATE: begin
                        if (mdio_start_reg[gi]) begin
                            mdio_valid_reg[gi] <= 1'b1;

                            state_reg[gi] <= WAIT_FOR_READY_STATE;
                        end
                    end
                    WAIT_FOR_READY_STATE: begin
                        if (mdio_ready) begin
                            mdio_valid_reg[gi] <= 1'b0;

                            if (mdio_op_reg[gi] == MDIO_READ) begin
                                mdio_rdata_ready_reg[gi] <= 1'b1;

                                state_reg[gi] <= WAIT_FOR_RDATA_STATE;
                            end else begin
                                state_reg[gi] <= IDLE_STATE;
                            end
                        end
                    end
                    WAIT_FOR_RDATA_STATE: begin
                        if (mdio_rdata_valid[gi]) begin
                            mdio_rdata_ready_reg[gi] <= 1'b0;
                            mdio_rdata_reg[gi] <= mdio_rdata[gi*16 +: 16];

                            state_reg[gi] <= IDLE_STATE;
                        end
                    end
                endcase
            end
        end
    end
endgenerate


endmodule

`resetall
