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
import pytest

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.axi import AxiWriteBus, AxiRamWrite
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSink
from cocotbext.axi.stream import define_stream

class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

        self.axis_data_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.clk, dut.rst)
        self.axis_desc_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "axis_dma_desc_write_len"), dut.clk, dut.rst)

    def set_idle_generator(self, generator=None):
        if generator:
            self.axis_data_sink.set_pause_generator(generator())

    async def cycle_reset(self):
        self.dut.rst.setimmediatevalue(0)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)


async def run_test(dut, idle_inserter=None):
    tb = TB(dut)


    tb.set_idle_generator(idle_inserter)
    tb.axis_data_sink.pause = True
    tb.axis_desc_sink.pause = True

    await tb.cycle_reset()

    for _ in range(5):
        tb.axis_desc_sink.pause = False

        while True:
            if (dut.axis_dma_desc_write_len_tvalid.value and dut.axis_dma_desc_write_len_tready.value):
                tb.axis_desc_sink.pause = True
                tb.axis_data_sink.pause = False
                break

            await RisingEdge(dut.clk)

        await RisingEdge(dut.clk)

        length_frame = await tb.axis_desc_sink.recv()
        length = length_frame.tdata

        while True:
            if (dut.m_axis_tvalid.value and dut.m_axis_tready.value and dut.m_axis_tlast.value):
                tb.axis_data_sink.pause = True
                break

            await RisingEdge(dut.clk)

        await RisingEdge(dut.clk)

        data_frame = await tb.axis_data_sink.recv(compact=True)
        data = data_frame.tdata

        tb.axis_data_sink.pause = True

        assert length[0] == len(data)

        await RisingEdge(dut.clk)


    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))

def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])

def cycle_not_ready():
    return itertools.cycle([0])

def cycle_ready():
    return itertools.cycle([1])


if cocotb.SIM_NAME:
    factory = TestFactory(run_test)
    factory.add_option("idle_inserter", [None, cycle_pause])
    factory.generate_tests()