#!/usr/bin/env python
"""
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
"""

import itertools
import logging
import os
import difflib

import cocotb_test.simulator

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Event
from cocotb.regression import TestFactory

from cocotbext.eth import GmiiFrame, RgmiiSource
from cocotbext.axi import AxiStreamBus, AxiStreamSink


class TB:
    def __init__(self, dut, speed=1000e6):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        self.rgmii_source = RgmiiSource(dut.rgmii_rxd, dut.rgmii_rx_ctl, dut.rgmii_rx_clk, dut.rx_rst)

        self.axis_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.axi_clk, dut.axi_rst)

        cocotb.start_soon(Clock(dut.axi_clk, 7, units="ns").start())
        cocotb.start_soon(Clock(dut.counter_clk, 5, units="ns").start())

        self.set_speed(speed)

    def set_speed(self, speed):
        if speed == 10e6:
            self.rgmii_source.mii_mode = True
            cocotb.start_soon(Clock(self.dut.rgmii_rx_clk, 400, units="ns").start())
        elif speed == 100e6:
            self.rgmii_source.mii_mode = True
            cocotb.start_soon(Clock(self.dut.rgmii_rx_clk, 40, units="ns").start())
        elif speed == 1000e6:
            self.rgmii_source.mii_mode = False
            cocotb.start_soon(Clock(self.dut.rgmii_rx_clk, 8, units="ns").start())
        else:
            raise AssertionError("Invalid speed!")

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.axis_sink.set_pause_generator(generator())

    async def reset(self):
        self.dut.axi_rst.setimmediatevalue(0)
        self.dut.counter_rst.setimmediatevalue(0)
        await RisingEdge(self.dut.axi_clk)
        await RisingEdge(self.dut.axi_clk)
        self.dut.axi_rst.value = 1
        self.dut.counter_rst.value = 1
        await RisingEdge(self.dut.axi_clk)
        await RisingEdge(self.dut.axi_clk)
        self.dut.axi_rst.value = 0
        self.dut.counter_rst.value = 0
        await RisingEdge(self.dut.axi_clk)
        await RisingEdge(self.dut.axi_clk)


async def run_test_rx(dut, payload_lengths=None, payload_data=None, backpressure_inserter=None, speed=1000e6, ifg=12):
    tb = TB(dut, speed)

    tb.rgmii_source.ifg = ifg


    await tb.reset()
    tb.set_backpressure_generator(backpressure_inserter)

    dut.ts_nsec.value = 1
    dut.ts_sec.value = 2
    dut.enable.value = 1
    dut.mii_select = 0 if speed == 1000e6 else 1

    for _ in range(100):
        await RisingEdge(dut.rx_clk)

    test_frames = [payload_data(x) for x in payload_lengths()]
    gmii_frames = list()

    for test_data in test_frames:
        test_frame = GmiiFrame.from_payload(test_data, tx_complete=Event())
        gmii_frames.append(test_frame)
        await tb.rgmii_source.send(test_frame)

    for i in range(len(test_frames)):
        gmii_frame = gmii_frames[i]
        test_frame = test_frames[i]

        await gmii_frame.tx_complete.wait()

        sfd_timestamp = gmii_frame.tx_complete.data.sim_time_sfd
        sfd_nsec_timestamp = sfd_timestamp % 10**9
        sfd_sec_timestamp = int(sfd_timestamp / 10**9)

        axis_frame = await tb.axis_sink.recv()
        axis_data = axis_frame.tdata

        assert len(axis_data) == len(test_frame) + 16, f"Frame 1: {axis_data}\nFrame 2 {test_frame}"
        assert axis_data[16:] == test_frame
        assert int.from_bytes(axis_data[0:4], "little", signed=False) == 2
        assert int.from_bytes(axis_data[4:8], "little", signed=False) == 1
        assert int.from_bytes(axis_data[8:12], "little", signed=False) == len(test_frame)
        assert int.from_bytes(axis_data[12:16], "little", signed=False) == len(test_frame)

    assert tb.axis_sink.empty()

    await RisingEdge(dut.rgmii_rx_clk)
    await RisingEdge(dut.rgmii_rx_clk)

async def run_test_bad_frame(dut, payload_data=None, backpressure_inserter=None, speed=1000e6, ifg=12):
    tb = TB(dut, speed)

    tb.rgmii_source.ifg = ifg

    await tb.reset()
    tb.set_backpressure_generator(backpressure_inserter)

    dut.ts_nsec.value = 400
    dut.ts_sec.value = 2
    dut.enable.value = 1
    dut.mii_select = 0 if speed == 1000e6 else 1

    for _ in range(100):
        await RisingEdge(dut.rx_clk)

    assert tb.axis_sink.empty()

    frame = GmiiFrame.from_payload(b'test data is a great thing but more bytes are required. Otherwise, padding is applied.', tx_complete=Event())
    frame.error = 15*[0] + [1, 0]

    await tb.rgmii_source.send(frame)
    await frame.tx_complete.wait()

    axis_frame = await tb.axis_sink.recv()
    axis_data = axis_frame.tdata

    assert len(axis_data) == len(frame.get_payload()) + 16, f"Frame 1: {axis_data}\nFrame 2 {frame.get_payload()}"
    assert axis_data[16:] == frame.get_payload()
    assert int.from_bytes(axis_data[0:4], "little", signed=False) == 3
    assert int.from_bytes(axis_data[4:8], "little", signed=False) == 400
    assert int.from_bytes(axis_data[8:12], "little", signed=False) == len(frame.get_payload())
    assert int.from_bytes(axis_data[12:16], "little", signed=False) == len(frame.get_payload())




def size_list():
    return list(range(64, 128)) + [512, 1514] + [64]*10 + \
        [64, 128, 256, 512, 1024, 64, 64, 64, 1500, 64, 64, 64, 1500, 1500]


def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))


def cycle_pause():
    return itertools.cycle([0, 0, 0, 1])


if cocotb.SIM_NAME:
    factory = TestFactory(run_test_bad_frame)
    factory.add_option("payload_data", [incrementing_payload])
    factory.add_option("backpressure_inserter", [None, cycle_pause])
    factory.add_option("speed", [1000e6, 100e6, 10e6])
    factory.generate_tests()

    factory = TestFactory(run_test_rx)
    factory.add_option("payload_lengths", [size_list])
    factory.add_option("payload_data", [incrementing_payload])
    factory.add_option("backpressure_inserter", [None, cycle_pause])
    factory.add_option("speed", [1000e6, 100e6, 10e6])
    factory.generate_tests()
