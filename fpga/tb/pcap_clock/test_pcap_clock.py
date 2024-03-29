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

CLOCK_PERIOD = 100_000_001

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

    clock = Clock(dut.clk, CLOCK_PERIOD, units="ns")  # Create a 8ns period clock on port clk
    cocotb.start_soon(clock.start())  # Start the clock

    await tb.reset()

    for _ in range(2):
        await FallingEdge(dut.clk)

    for _ in range(int(1_000_000_000 / CLOCK_PERIOD)):
        await FallingEdge(dut.clk)

    assert dut.sec.value == 1
    assert dut.nsec.value.integer == 200000012

    for _ in range(int(1_000_000_000 / CLOCK_PERIOD)):
        await FallingEdge(dut.clk)

    assert dut.sec.value == 2
    assert dut.nsec.value.integer == 100000021


if cocotb.SIM_NAME:
    factory = TestFactory(run_test)
    factory.generate_tests()