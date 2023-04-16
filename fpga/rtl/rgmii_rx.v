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
 * RGMII Frame Receiver: RGMII in, AXIS out (prepended by a timestamp)
 */
module rgmii_rx #
(
    parameter TARGET = "GENERIC",
    parameter IODDR_STYLE = "IODDR",
    parameter CLOCK_INPUT_STYLE = "BUFR",
    parameter DATA_WIDTH = 8,
    parameter USER_WIDTH = 1
)
(
    input  wire                      rst,

    output wire                      rx_clk,
    output wire                      rx_rst,

    input  wire                      enable,
    input  wire                      mii_select,

    output wire                      busy,

    /*
     * RGMII RX interface
     */
    input  wire                      rgmii_rx_clk,
    input  wire [3:0]                rgmii_rxd,
    input  wire                      rgmii_rx_ctl,

    /*
     * AXI output
     */
    output wire [DATA_WIDTH-1:0]     rx_axis_tdata,
    output wire                      rx_axis_tvalid,
    output wire                      rx_axis_tlast,
    output wire [USER_WIDTH-1:0]     rx_axis_tuser,

    output wire                      rx_start_packet,
    output wire                      rx_error_bad_frame,
    output wire                      rx_error_bad_fcs
);

// synchronize reset
reg [3:0] rx_rst_reg = 4'hf;
assign rx_rst = rx_rst_reg[0];

always @(posedge gmii_rx_clk or posedge rst) begin
    if (rst || soft_reset_reg) begin
        rx_rst_reg <= 4'hf;
    end else begin
        rx_rst_reg <= {1'b0, rx_rst_reg[3:1]};
    end
end


wire gmii_rx_ctl_1;
wire gmii_rx_ctl_2;

wire gmii_rx_clk;
wire [7:0] gmii_rxd;
wire gmii_rx_dv = gmii_rx_ctl_1;
wire gmii_rx_er = gmii_rx_ctl_1 ^ gmii_rx_ctl_2;

assign rx_clk = gmii_rx_clk;

ssio_ddr_in #
(
    .TARGET(TARGET),
    .CLOCK_INPUT_STYLE(CLOCK_INPUT_STYLE),
    .IODDR_STYLE(IODDR_STYLE),
    .WIDTH(5)
)
rx_ssio_ddr_inst (
    .input_clk(rgmii_rx_clk),
    .input_d({rgmii_rxd, rgmii_rx_ctl}),
    .output_clk(gmii_rx_clk),
    .output_q1({gmii_rxd[3:0], gmii_rx_ctl_1}),
    .output_q2({gmii_rxd[7:4], gmii_rx_ctl_2})
);

localparam PTP_TS_WIDTH = 64;

axis_gmii_rx #(
    .DATA_WIDTH(DATA_WIDTH),
    .PTP_TS_WIDTH(PTP_TS_WIDTH),
    .PTP_TS_ENABLE(0),
    .USER_WIDTH(USER_WIDTH)
)
axis_gmii_rx_inst (
    .clk(gmii_rx_clk),
    .rst(rx_rst),
    .gmii_rxd(gmii_rxd),
    .gmii_rx_dv(gmii_rx_dv),
    .gmii_rx_er(gmii_rx_er),
    .m_axis_tdata(rx_axis_tdata),
    .m_axis_tvalid(rx_axis_tvalid),
    .m_axis_tlast(rx_axis_tlast),
    .m_axis_tuser(rx_axis_tuser),
    .ptp_ts({PTP_TS_WIDTH{1'b0}}),
    .clk_enable(rx_enable),
    .mii_select(mii_select),
    .start_packet(start_packet),
    .error_bad_frame(rx_error_bad_frame),
    .error_bad_fcs(rx_error_bad_fcs)
);

wire rx_enable = state_reg != STATE_DISABLED;
wire start_packet;

assign rx_start_packet = start_packet & rx_enable;
assign busy = state_reg == STATE_TRANSMITTING;

localparam [1:0]
    STATE_DISABLED = 2'd0,
    STATE_IDLE = 2'd1,
    STATE_TRANSMITTING = 2'd2;

reg [1:0] state_reg = STATE_IDLE;
reg soft_reset_reg = 1'b0;

always @(posedge gmii_rx_clk) begin
    state_reg <= state_reg;
    soft_reset_reg <= 1'b0;

    case(state_reg)
        STATE_DISABLED: begin
            if (start_packet) begin
                // workaround for delayed start packet recognition
                soft_reset_reg = 1'b1;
            end else if (enable) begin
                state_reg <= STATE_IDLE;
            end
        end
        STATE_IDLE: begin
            if (start_packet) begin
                state_reg <= STATE_TRANSMITTING;
            end else if (!enable) begin
                state_reg <= STATE_DISABLED;
            end
        end
        STATE_TRANSMITTING: begin
            if (rx_axis_tvalid && rx_axis_tlast) begin
                if (enable) begin
                    state_reg <= STATE_IDLE;
                end else begin
                    state_reg <= STATE_DISABLED;
                end
            end
        end
    endcase

    if (rx_rst) begin
        state_reg <= STATE_DISABLED;
    end
end

endmodule

`resetall