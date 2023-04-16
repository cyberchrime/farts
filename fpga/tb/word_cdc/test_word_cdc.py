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

class TB:
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.input_clk, 3, units="ns").start())
        cocotb.start_soon(Clock(dut.output_clk, 8, units="ns").start())

    async def reset(self):
        self.dut.rst.setimmediatevalue(0)
        await RisingEdge(self.dut.output_clk)
        await RisingEdge(self.dut.output_clk)
        self.dut.rst.value = 1
        await RisingEdge(self.dut.output_clk)
        await RisingEdge(self.dut.output_clk)
        self.dut.rst.value = 0
        await RisingEdge(self.dut.output_clk)
        await RisingEdge(self.dut.output_clk)


async def run_test(dut):

    tb = TB(dut)

    input_clock = Clock(dut.input_clk, 3, units="ns")  # Create a 8ns period clock on port clk
    output_clock = Clock(dut.output_clk, 8, units="ns")  # Create a 8ns period clock on port clk
    cocotb.start_soon(input_clock.start())  # Start the clock
    cocotb.start_soon(output_clock.start())  # Start the clock

    dut.input_data.value = 0x12345678

    await tb.reset()

    for _ in range(4):
        await FallingEdge(dut.output_clk)

    dut.input_data.value = 0xdeadbeef

    for i in range(0x1234, 0x100000, 0x1234):
        dut.input_data.value = i
        await FallingEdge(dut.input_clk)


if cocotb.SIM_NAME:
    factory = TestFactory(run_test)
    factory.generate_tests()