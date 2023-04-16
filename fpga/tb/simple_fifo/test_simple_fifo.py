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
import random

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
    tb = TB(dut)
    test_values = get_random_test_values(32)

    clock = Clock(dut.clk, 8, units="ns")
    cocotb.start_soon(clock.start())

    dut.output_ready.value = 0
    dut.input_data.value = 0
    dut.input_valid.value = 0
    await tb.reset()


    for _ in range(2):
        await FallingEdge(dut.clk)

    dut.input_data.value = test_values[0]

    # should not store data yet
    for _ in range(2):
        await FallingEdge(dut.clk)
        assert dut.output_valid.value != 1

    dut.input_valid.value = 1

    # store data now
    await FallingEdge(dut.clk)

    dut.input_valid.value = 0
    assert dut.output_valid.value != 1

    # not empty -> should show valid output
    for _ in range(2):
        await FallingEdge(dut.clk)
        assert dut.output_valid.value == 1

    # fill with some data
    for i in range(4):
        await FallingEdge(dut.clk)
        dut.input_valid.value = 1
        dut.input_data.value = test_values[i+1]

    dut.input_valid.value = 0

    # still shows valid
    for _ in range(2):
        await FallingEdge(dut.clk)
        assert dut.output_valid.value == 1

    dut.output_ready.value = 1

    # read some values
    for i in range(4):
        await FallingEdge(dut.clk)
        assert dut.output_valid.value != 1
        dut.output_data.value = test_values[i]
        await FallingEdge(dut.clk)

    dut.output_ready.value = 0

    # fill with more data than DEPTH -> discard after limit
    for i in range(17):
        dut.input_valid.value = 1
        dut.input_data.value = test_values[i+5]
        await FallingEdge(dut.clk)

    dut.input_valid.value = 0
    dut.output_ready.value = 1
    await FallingEdge(dut.clk)

    for i in range(15):
        await FallingEdge(dut.clk)
        dut.output_data.value = test_values[i+5]
        assert dut.output_valid.value == 1
        await FallingEdge(dut.clk)

    for i in range(4):
        assert dut.output_valid.value == 0
        await FallingEdge(dut.clk)

    for _ in range(2):
        await FallingEdge(dut.clk)
        assert dut.output_valid.value == 0

    dut.input_valid.value = 1
    dut.input_data.value = test_values[20]

    await FallingEdge(dut.clk)
    dut.input_valid.value = 0

    await FallingEdge(dut.clk)

    dut.input_valid.value = 1
    dut.input_valid.output_ready = 1
    dut.input_data.value = test_values[21]

    await FallingEdge(dut.clk)

    dut.input_valid.value = 0
    dut.input_valid.output_ready = 0




def get_random_test_values(len):
    random.seed(3)
    return [random.randint(0, 0xffff) for _ in range(len)]


if cocotb.SIM_NAME:
    for test in [run_test]:
        factory = TestFactory(test)
        factory.generate_tests()
