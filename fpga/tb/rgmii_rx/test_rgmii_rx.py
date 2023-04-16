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

import cocotb_test.simulator

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Event
from cocotb.regression import TestFactory
from cocotb.result import SimTimeoutError

from cocotbext.eth import GmiiFrame, RgmiiSource
from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink

PERIOD_UNITS = 'ns'

class TB:
    def __init__(self, dut, speed=1000e6):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        self.rgmii_source = RgmiiSource(dut.rgmii_rxd, dut.rgmii_rx_ctl, dut.rgmii_rx_clk, dut.rst, mii_select=dut.mii_select)

        self.axis_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "rx_axis"), dut.rx_clk, dut.rx_rst)

        self.period = self.set_speed(speed)


    def set_speed(self, speed):
        if speed == 10e6:
            period = 400
            self.dut.mii_select.value = 1
        elif speed == 100e6:
            period = 40
            self.dut.mii_select.value = 1
        elif speed == 1000e6:
            period = 8
            self.dut.mii_select.value = 0
        else:
            raise AssertionError("Invalid speed!")

        cocotb.start_soon(Clock(self.dut.rgmii_rx_clk, period, units=PERIOD_UNITS).start())
        return period

    async def reset(self):
        self.dut.rst.setimmediatevalue(0)
        await RisingEdge(self.dut.rx_clk)
        await RisingEdge(self.dut.rx_clk)
        self.dut.rst.value = 1
        await RisingEdge(self.dut.rx_clk)
        await RisingEdge(self.dut.rx_clk)
        self.dut.rst.value = 0
        await RisingEdge(self.dut.rx_clk)
        await RisingEdge(self.dut.rx_clk)


async def run_test_disable(dut, payload_lengths=None, payload_data=None, speed=1000e6, ifg=12):
    tb = TB(dut, speed)
    tb.rgmii_source.ifg = ifg
    await tb.reset()

    await ClockCycles(dut.rx_clk, 100)

    payload = payload_data(64)

    # disable while idle
    tb.dut.enable.value = 1
    test_frame = GmiiFrame.from_payload(payload, tx_complete=Event())
    await tb.rgmii_source.send(test_frame)
    print("test")
    rx_frame = await tb.axis_sink.recv()
    assert rx_frame.tdata == payload
    assert tb.axis_sink.empty()
    assert tb.rgmii_source.empty() and tb.rgmii_source.idle()

    tb.dut.enable.value = 0

    # enable while idle
    await ClockCycles(dut.rx_clk, 2)
    test_frame = GmiiFrame.from_payload(payload, tx_complete=Event())
    await tb.rgmii_source.send(test_frame)
    assert tb.axis_sink.empty()
    await test_frame.tx_complete.wait()
    assert tb.axis_sink.empty()

    await ClockCycles(dut.rx_clk, 5)

    tb.dut.enable.value = 1

    # disable while receiving
    try:
        tb.rgmii_source.send_nowait(test_frame)
        await cocotb.triggers.with_timeout(RisingEdge(tb.dut.start_packet), tb.period * 100, timeout_unit=PERIOD_UNITS)
        await ClockCycles(dut.rx_clk, 10)
        tb.dut.enable.value = 0

        await ClockCycles(dut.rx_clk, 10)
        assert not tb.axis_sink.idle()
        rx_frame = await tb.axis_sink.recv()
        assert tb.axis_sink.empty()
        rx_frame.tdata = payload
    except SimTimeoutError:
        assert False, "No start_packet received"

    # enable while receiving
    tb.rgmii_source.send_nowait(test_frame)
    await ClockCycles(dut.rx_clk, 40)
    tb.dut.enable.value = 1
    await ClockCycles(dut.rx_clk, 10)
    assert tb.axis_sink.idle()

    assert tb.rgmii_source.wait()

    # disable one cycle before receiving start_packet
    tb.dut.enable.value = 1
    await ClockCycles(dut.rx_clk, 2)

    try:
        test_frame = GmiiFrame.from_payload(payload, tx_complete=Event())
        tb.rgmii_source.send_nowait(test_frame)
        await cocotb.triggers.with_timeout(RisingEdge(tb.dut.axis_gmii_rx_inst.start_packet_next), tb.period * 200, timeout_unit=PERIOD_UNITS)
        tb.dut.enable.value = 0
        await ClockCycles(dut.rx_clk, 30)
        assert tb.axis_sink.idle()
        await test_frame.tx_complete.wait()
    except SimTimeoutError:
        assert False, "No start_packet received"


async def run_test_rx(dut, payload_lengths=None, payload_data=None, speed=1000e6, ifg=12):
    tb = TB(dut, speed)
    tb.rgmii_source.ifg = ifg
    await tb.reset()
    tb.dut.enable.value = 1

    await ClockCycles(dut.rx_clk, 100)

    test_frames = [payload_data(x) for x in payload_lengths()]

    for test_data in test_frames:
        test_frame = GmiiFrame.from_payload(test_data)
        await tb.rgmii_source.send(test_frame)

    for test_data in test_frames:
        rx_frame = await tb.axis_sink.recv()

        assert rx_frame.tdata == test_data
        assert rx_frame.tuser == 0

    assert tb.axis_sink.empty()

    await RisingEdge(dut.rx_clk)
    await RisingEdge(dut.rx_clk)

def size_list():
    return list(range(60, 128)) + [512, 1514] + [60]*10


def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))


def cycle_en():
    return itertools.cycle([0, 0, 0, 1])


if cocotb.SIM_NAME:
    for test in [run_test_disable, run_test_rx]:
        factory = TestFactory(test)
        factory.add_option("payload_lengths", [size_list])
        factory.add_option("payload_data", [incrementing_payload])
        factory.add_option("speed", [1000e6, 100e6, 10e6])
        factory.generate_tests()