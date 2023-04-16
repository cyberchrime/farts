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
from cocotb.triggers import RisingEdge, FallingEdge
from cocotb.regression import TestFactory

from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink


class TB:
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 8, units="ns").start())

        self.axis_source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), dut.clk, dut.rst)
        self.axis_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.clk, dut.rst)

    async def reset(self):
        self.dut.rst.setimmediatevalue(0)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)


async def run_test(dut):
    axis_tdata = incrementing_payload(64)
    axis_tdata_insert = 0x0123456789abcdef

    tb = TB(dut)

    clock = Clock(dut.clk, 8, units="ns")  # Create a 8ns period clock on port clk
    cocotb.start_soon(clock.start())  # Start the clock

    dut.insert_value.value = axis_tdata_insert

    await tb.reset()

    for _ in range(2):
        await FallingEdge(dut.clk)

    await tb.axis_source.send(axis_tdata)

    await FallingEdge(dut.clk)



    await tb.axis_source.wait()

    for _ in range(15):
        await FallingEdge(dut.clk)

    data = await tb.axis_sink.recv()
    assert data.tdata == bytes(axis_tdata[:8]) + (axis_tdata_insert).to_bytes(8, byteorder='big') + bytes(axis_tdata[8:])

if cocotb.SIM_NAME:
    factory = TestFactory(run_test)
    factory.generate_tests()

def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))