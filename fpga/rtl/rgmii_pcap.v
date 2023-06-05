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
 * RGMII Stream to PCAP Stream converter
 */
module rgmii_pcap #
(
    // Data width of AXI stream made from RGMII stream
    parameter AXIS_DATA_WIDTH = 8,
    // Width of AXI stream tuser signal
    parameter AXIS_USER_WIDTH = 1,
    // depth of internal FIFO in bytes
    parameter FIFO_DEPTH = 2**13,
    // DATA WIDTH of output AXI DMA
    parameter AXI_DATA_WIDTH = 64,
    // tkeep signal width (words per cycle)
    parameter KEEP_WIDTH = ((AXI_DATA_WIDTH+7)/8),
    // width of frame length counter
    parameter FRAME_LEN_WIDTH = 16,
    // Clock period
    parameter CLOCK_PERIOD = 4,
    // target ("SIM", "GENERIC", "XILINX", "ALTERA")
    parameter TARGET = "GENERIC",
    // IODDR style ("IODDR", "IODDR2")
    // Use IODDR for Virtex-4, Virtex-5, Virtex-6, 7 Series, Ultrascale
    // Use IODDR2 for Spartan-6
    parameter IODDR_STYLE = "IODDR",
    // Clock input style ("BUFG", "BUFR", "BUFIO", "BUFIO2")
    // Use BUFR for Virtex-6, 7-series
    // Use BUFG for Virtex-5, Spartan-6, Ultrascale
    parameter CLOCK_INPUT_STYLE = "BUFR"
)(
    input  wire                       axi_clk,
    input  wire                       axi_rst,

    input  wire                       counter_clk,
    input  wire                       counter_rst,

    /*
     * RGMII interface
     */
    input  wire                       rgmii_rx_clk,
    input  wire [3:0]                 rgmii_rxd,
    input  wire                       rgmii_rx_ctl,

    /*
     * AXI4-Stream Master Interface
     */
    output wire [AXI_DATA_WIDTH-1:0]  m_axis_tdata,
    output wire                       m_axis_tvalid,
    output wire                       m_axis_tlast,
    output wire [AXIS_USER_WIDTH-1:0] m_axis_tuser,
    output wire [KEEP_WIDTH-1:0]      m_axis_tkeep,
    input  wire                       m_axis_tready,

    output wire                       fifo_overflow,
    output wire                       fifo_bad_frame,
    output wire                       fifo_good_frame,
    output wire                       start_packet,
    output wire                       bad_frame,
    output wire                       bad_fcs,

    input  wire [31:0]                ts_sec,
    input  wire [31:0]                ts_nsec,

    output wire                       busy,

    input  wire                       enable,
    input  wire                       mii_select
);

// depth of internal FIFO in words
localparam FIFO_WORD_DEPTH = FIFO_DEPTH/KEEP_WIDTH;
// TODO: fix s_overflow of ASYNC FIFO


wire rx_clk;
wire rx_rst;

wire [7:0] rx_axis_tdata;
wire rx_axis_tvalid;
wire rx_axis_tready;
wire rx_axis_tlast;
wire [AXIS_USER_WIDTH-1:0] rx_axis_tuser;

wire [AXI_DATA_WIDTH-1:0] m_axis_packet_tdata;
wire m_axis_packet_tvalid;
wire m_axis_packet_tready_final = m_axis_packet_tready_reg && m_axis_packet_tready;
reg m_axis_packet_tready_reg;
wire m_axis_packet_tready;
wire m_axis_packet_tlast;
wire [KEEP_WIDTH-1:0] m_axis_packet_tkeep;
wire [AXIS_USER_WIDTH-1:0] m_axis_packet_tuser;


wire rx_start_packet;
wire rx_bad_frame;
wire rx_bad_fcs;
wire s_good_frame, s_bad_frame, s_overflow;

async_edge_detect start_packet_edge_detect (
    .clk(axi_clk),
    .rst(axi_rst),
    .sig(rx_start_packet),
    .rise(start_packet),
    .fall()
);

async_edge_detect bad_frame_edge_detect (
    .clk(axi_clk),
    .rst(axi_rst),
    .sig(rx_bad_frame),
    .rise(bad_frame),
    .fall()
);

async_edge_detect bad_fcs_edge_detect (
    .clk(axi_clk),
    .rst(axi_rst),
    .sig(rx_bad_fcs),
    .rise(bad_fcs),
    .fall()
);


wire enable_sync;
wire mii_select_sync;

word_cdc #
(
    .DATA_WIDTH(2),
    .DEPTH(2)
)
mii_select_synchronize (
    .input_clk(axi_clk),
    .output_clk(rx_clk),
    .rst(1'b0), // no reset required because not critical

    .input_data({mii_select, enable}),
    .output_data({mii_select_sync, enable_sync})
);

rgmii_rx #
(
   .TARGET(TARGET),
   .IODDR_STYLE(IODDR_STYLE),
   .CLOCK_INPUT_STYLE(CLOCK_INPUT_STYLE),
   .DATA_WIDTH(AXIS_DATA_WIDTH)
)
rgmii_rx_inst (
    .rst(axi_rst),
    .rx_clk(rx_clk),
    .rx_rst(rx_rst),
    .busy(busy),
    .enable(enable_sync),
    .mii_select(mii_select_sync),
    .rgmii_rx_clk(rgmii_rx_clk),
    .rgmii_rxd(rgmii_rxd),
    .rgmii_rx_ctl(rgmii_rx_ctl),
    .rx_axis_tdata(rx_axis_tdata),
    .rx_axis_tvalid(rx_axis_tvalid),
    .rx_axis_tlast(rx_axis_tlast),
    .rx_axis_tuser(rx_axis_tuser),
    .rx_start_packet(rx_start_packet),
    .rx_error_bad_frame(rx_bad_frame),
    .rx_error_bad_fcs(rx_bad_fcs)
);

axis_async_fifo_adapter # (
    .S_DATA_WIDTH(AXIS_DATA_WIDTH),
    .M_DATA_WIDTH(AXI_DATA_WIDTH),
    .DEST_ENABLE(0),
    .DEST_WIDTH(1),
    .ID_ENABLE(0),
    .ID_WIDTH(1),
    .DEPTH(FIFO_DEPTH),
    .DROP_WHEN_FULL(1),
    .DROP_BAD_FRAME(0),
    .FRAME_FIFO(1)
)
rx_data_fifo (
    // AXI input
    .s_clk(rx_clk),
    .s_rst(rx_rst),
    .s_axis_tdata(rx_axis_tdata),
    .s_axis_tkeep(1'b0),
    .s_axis_tvalid(rx_axis_tvalid),
    .s_axis_tready(),
    .s_axis_tlast(rx_axis_tlast),
    .s_axis_tid(1'b0),
    .s_axis_tdest(1'b0),
    .s_axis_tuser(rx_axis_tuser),
    // AXI output
    .m_clk(axi_clk),
    .m_rst(axi_rst),
    .m_axis_tdata(m_axis_packet_tdata),
    .m_axis_tkeep(m_axis_packet_tkeep),
    .m_axis_tvalid(m_axis_packet_tvalid),
    .m_axis_tready(m_axis_packet_tready_final),
    .m_axis_tlast(m_axis_packet_tlast),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(m_axis_packet_tuser),
    // Status
    .s_status_overflow(s_overflow),
    .s_status_bad_frame(s_bad_frame),
    .s_status_good_frame(s_good_frame),
    .m_status_overflow(fifo_overflow),
    .m_status_bad_frame(fifo_bad_frame),
    .m_status_good_frame(fifo_good_frame)
);

wire [31:0] ts_nsec_rx;
wire [31:0] ts_sec_rx;

localparam CDC_DEPTH = 2;

word_cdc # (
    .DATA_WIDTH(64),
    .DEPTH(CDC_DEPTH)
)
timestamp_cdc (
    .input_clk(counter_clk),
    .output_clk(rx_clk),
    .rst(1'b0), // no reset required because it takes some cycles till SFD arrives

    .input_data({ts_nsec, ts_sec}),
    .output_data({ts_nsec_rx, ts_sec_rx})
);

// delay start_frame signal as this is the amount of time required for
// the timestamp to cross the clock domains
pipeline # (
    .DATA_WIDTH(1),
    .DEPTH(CDC_DEPTH)
)
start_packet_pipeline (
    .clk(rx_clk),
    .rst(rx_rst),

    .data_in(rx_start_packet),
    .data_out(s_axis_ts_tvalid)
);


wire [63:0] m_axis_timestamp_tdata;
wire m_axis_timestamp_tvalid;
reg m_axis_timestamp_tready_reg = 1'b0;

wire [63:0] axis_timestamp_tdata;
wire axis_timestamp_tvalid = s_good_frame || s_bad_frame || s_overflow;
wire axis_timestamp_async_tvalid = s_good_frame;

wire s_axis_ts_tvalid;

// This FIFO is used to temporarily store the timestamps until the packet FIFO
// knows whether is dropping the corresponding frame or keeping it
// Large enough to keep 1522/64 (Largest frame size divided by smallest frame size)
// and always accept new timestamps
axis_fifo # (
    .DATA_WIDTH(64),
    .USER_ENABLE(0),
    .USER_WIDTH(1),
    .LAST_ENABLE(0),
    .DEST_ENABLE(0),
    .DEST_WIDTH(1),
    .ID_ENABLE(0),
    .ID_WIDTH(1),
    .DEPTH(32),
    .KEEP_ENABLE(0),
    .FRAME_FIFO(0)
)
timestamp_fifo (
    .clk(rx_clk),
    .rst(rx_rst),

    // AXI input
    .s_axis_tdata({ts_nsec_rx, ts_sec_rx}),
    .s_axis_tkeep(8'b1),
    .s_axis_tvalid(s_axis_ts_tvalid),
    .s_axis_tready(),
    .s_axis_tlast(1'b0),
    .s_axis_tid(1'b0),
    .s_axis_tdest(1'b0),
    .s_axis_tuser(1'b0),
    // AXI output
    .m_axis_tdata(axis_timestamp_tdata),
    .m_axis_tkeep(),
    .m_axis_tvalid(),
    .m_axis_tready(axis_timestamp_tvalid),
    .m_axis_tlast(),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(),
    // Status
    .status_overflow(),
    .status_bad_frame(),
    .status_good_frame()
);

axis_async_fifo # (
    .DATA_WIDTH(64),
    .USER_ENABLE(0),
    .USER_WIDTH(1),
    .LAST_ENABLE(0),
    .DEST_ENABLE(0),
    .DEST_WIDTH(1),
    .ID_ENABLE(0),
    .ID_WIDTH(1),
    .DEPTH(FIFO_DEPTH/64),
    .KEEP_ENABLE(0),
    .FRAME_FIFO(0)
)
async_timestamp_fifo (
    // AXI input
    .s_clk(rx_clk),
    .s_rst(rx_rst),
    .s_axis_tdata(axis_timestamp_tdata),
    .s_axis_tkeep(8'b1),
    .s_axis_tvalid(axis_timestamp_async_tvalid),
    .s_axis_tready(),
    .s_axis_tlast(1'b0),
    .s_axis_tid(1'b0),
    .s_axis_tdest(1'b0),
    .s_axis_tuser(1'b0),
    // AXI output
    .m_clk(axi_clk),
    .m_rst(axi_rst),
    .m_axis_tdata(m_axis_timestamp_tdata),
    .m_axis_tkeep(),
    .m_axis_tvalid(m_axis_timestamp_tvalid),
    .m_axis_tready(m_axis_timestamp_tready_reg),
    .m_axis_tlast(),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(),
    // Status
    .s_status_overflow(),
    .s_status_bad_frame(),
    .s_status_good_frame(),
    .m_status_overflow(),
    .m_status_bad_frame(),
    .m_status_good_frame()
);

wire [FRAME_LEN_WIDTH-1:0] frame_len, frame_len_piped;
wire frame_len_valid, frame_len_valid_piped;

wire [FRAME_LEN_WIDTH-1:0] m_axis_frame_len_tdata, s_axis_frame_len_tdata;
wire m_axis_frame_len_tvalid, s_axis_frame_len_tvalid;
reg m_axis_frame_len_tready_reg;

assign s_axis_frame_len_tvalid = frame_len_valid_piped && s_good_frame;
assign s_axis_frame_len_tdata = frame_len_piped;

axis_frame_len # (
    .DATA_WIDTH(8),
    .LEN_WIDTH(FRAME_LEN_WIDTH)
)
axis_frame_len_inst (
    .clk(rx_clk),
    .rst(rx_rst),

    .monitor_axis_tkeep(1'b1),
    .monitor_axis_tvalid(rx_axis_tvalid),
    .monitor_axis_tready(1'b1),
    .monitor_axis_tlast(rx_axis_tlast),

    .frame_len(frame_len),
    .frame_len_valid(frame_len_valid)
);

pipeline # (
    .DEPTH(2),
    .DATA_WIDTH(FRAME_LEN_WIDTH+1)
)
frame_len_pipeline (
    .clk(rx_clk),
    .rst(rx_rst),

    .data_in({frame_len, frame_len_valid}),
    .data_out({frame_len_piped, frame_len_valid_piped})
);

axis_async_fifo # (
    .DATA_WIDTH(FRAME_LEN_WIDTH),
    .USER_ENABLE(0),
    .USER_WIDTH(1),
    .LAST_ENABLE(0),
    .DEST_ENABLE(0),
    .DEST_WIDTH(1),
    .ID_ENABLE(0),
    .ID_WIDTH(1),
    .DEPTH(FIFO_DEPTH/64),
    .FRAME_FIFO(0)
)
frame_len_fifo (
    // AXI input
    .s_clk(rx_clk),
    .s_rst(rx_rst),
    .s_axis_tdata(s_axis_frame_len_tdata),
    .s_axis_tkeep(2'b11),
    .s_axis_tvalid(s_axis_frame_len_tvalid),
    .s_axis_tready(),
    .s_axis_tlast(1'b0),
    .s_axis_tid(1'b0),
    .s_axis_tdest(1'b0),
    .s_axis_tuser(1'b0),
    // AXI output
    .m_clk(axi_clk),
    .m_rst(axi_rst),
    .m_axis_tdata(m_axis_frame_len_tdata),
    .m_axis_tkeep(),
    .m_axis_tvalid(m_axis_frame_len_tvalid),
    .m_axis_tready(m_axis_frame_len_tready_reg),
    .m_axis_tlast(),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(),
    // Status
    .s_status_overflow(),
    .s_status_bad_frame(),
    .s_status_good_frame(),
    .m_status_overflow(),
    .m_status_bad_frame(),
    .m_status_good_frame()
);

localparam STATE_WIDTH = 2;
localparam [STATE_WIDTH-1:0]
    IDLE_STATE = 2'd0,
    PREPARE_STATE = 2'd1,
    TRANSMISSION_STATE = 2'd2,
    FINISH_STATE = 2'd3;
reg [STATE_WIDTH-1:0] state_reg = IDLE_STATE;


always @(posedge axi_clk) begin
    if (axi_rst) begin
        m_axis_packet_tready_reg <= 1'b0;
        m_axis_frame_len_tready_reg <= 1'b0;
        m_axis_timestamp_tready_reg <= 1'b0;

        state_reg = IDLE_STATE;
    end else begin
        m_axis_packet_tready_reg <= m_axis_packet_tready_reg;
        m_axis_frame_len_tready_reg <= m_axis_frame_len_tready_reg;
        m_axis_timestamp_tready_reg <= m_axis_timestamp_tready_reg;

        state_reg <= state_reg;

        case (state_reg)
            IDLE_STATE: begin
                if (m_axis_packet_tvalid && m_axis_timestamp_tvalid && m_axis_frame_len_tvalid) begin
                    m_axis_packet_tready_reg <= 1'b0;
                    m_axis_frame_len_tready_reg <= 1'b1;
                    m_axis_timestamp_tready_reg <= 1'b1;

                    state_reg <= TRANSMISSION_STATE;
                end
            end
            TRANSMISSION_STATE: begin
                m_axis_frame_len_tready_reg <= 1'b0;
                m_axis_timestamp_tready_reg <= 1'b0;
                m_axis_packet_tready_reg <= 1'b1;

                if (m_axis_packet_tlast && m_axis_tready) begin
                    state_reg <= FINISH_STATE;
                    m_axis_packet_tready_reg <= 1'b0;
                end
            end
            FINISH_STATE: begin
                // wait till AXI Stream prepending pipeline is cleared
                if (m_axis_tlast && m_axis_tready) begin
                    if (m_axis_packet_tvalid && m_axis_timestamp_tvalid && m_axis_frame_len_tvalid) begin
                        m_axis_packet_tready_reg <= 1'b0;
                        m_axis_frame_len_tready_reg <= 1'b1;
                        m_axis_timestamp_tready_reg <= 1'b1;

                        state_reg <= TRANSMISSION_STATE;
                    end else begin
                        state_reg <= IDLE_STATE;
                    end
                end
            end
        endcase
    end
end

wire [31:0] frame_len_prepend_value = {{(32-FRAME_LEN_WIDTH){1'b0}}, m_axis_frame_len_tdata};

wire m_axis_packet_tvalid_int = m_axis_packet_tready_reg ? m_axis_packet_tvalid : 1'b0;
wire [AXI_DATA_WIDTH-1:0] m_axis_tdata_int;
wire m_axis_tvalid_int;
wire m_axis_tready_int;
wire m_axis_tlast_int;
wire [KEEP_WIDTH-1:0] m_axis_tkeep_int;
wire [AXIS_USER_WIDTH-1:0] m_axis_tuser_int;

axis_prepend #
(
    .DATA_WIDTH(AXI_DATA_WIDTH),
    .PREPEND_VALUE_WIDTH(AXI_DATA_WIDTH),
    .USER_WIDTH(AXIS_USER_WIDTH),
    .DELAY(0),
    .LITTLE_ENDIAN(0)
)
axis_frame_len_prepend (
    .clk(axi_clk),
    .rst(axi_rst),

    /*
     * AXI4-Stream input
     */
    .s_axis_tdata(m_axis_packet_tdata),
    .s_axis_tvalid(m_axis_packet_tvalid_int),
    .s_axis_tready(m_axis_packet_tready),
    .s_axis_tlast(m_axis_packet_tlast),
    .s_axis_tuser(m_axis_packet_tuser),
    .s_axis_tkeep(m_axis_packet_tkeep),

    /*
     * AXI4-Stream output
     */
    .m_axis_tdata(m_axis_tdata_int),
    .m_axis_tvalid(m_axis_tvalid_int),
    .m_axis_tready(m_axis_tready_int),
    .m_axis_tlast(m_axis_tlast_int),
    .m_axis_tuser(m_axis_tuser_int),
    .m_axis_tkeep(m_axis_tkeep_int),

    .prepend_value({frame_len_prepend_value, frame_len_prepend_value}),

    .start_packet(m_axis_frame_len_tready_reg)
);

axis_prepend #
(
    .DATA_WIDTH(AXI_DATA_WIDTH),
    .PREPEND_VALUE_WIDTH(AXI_DATA_WIDTH),
    .USER_WIDTH(AXIS_USER_WIDTH),
    .DELAY(0),
    .LITTLE_ENDIAN()
)
axis_ts_prepend (
    .clk(axi_clk),
    .rst(axi_rst),

    /*
     * AXI4-Stream input
     */
    .s_axis_tdata(m_axis_tdata_int),
    .s_axis_tvalid(m_axis_tvalid_int),
    .s_axis_tready(m_axis_tready_int),
    .s_axis_tlast(m_axis_tlast_int),
    .s_axis_tuser(m_axis_tuser_int),
    .s_axis_tkeep(m_axis_tkeep_int),

    /*
     * AXI4-Stream output
     */
    .m_axis_tdata(m_axis_tdata),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tready(m_axis_tready),
    .m_axis_tlast(m_axis_tlast),
    .m_axis_tuser(m_axis_tuser),
    .m_axis_tkeep(m_axis_tkeep),

    .prepend_value(m_axis_timestamp_tdata),

    .start_packet(m_axis_timestamp_tready_reg)
);

assign [63:0] axis_timestamp_tdata_ext = {axis_timestamp_tdata[63:1], dropped_reg};

reg dropped_reg = 0;

always @(rgmii_clk) begin
	dropped_reg <= dropped_reg | rx_axis_tuser;

    if (axis_timestamp_tvalid && axis_timestamp_async_tvalid) begin
		dropped_reg <= 1'b0;
    end
end


endmodule

`resetall
