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
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
from cocotb.regression import TestFactory

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


# From https://rosettacode.org/wiki/Gray_code#Python:_on_integers
def gray_encode(n):
    return n ^ n >> 1


# From https://rosettacode.org/wiki/Gray_code#Python:_on_integers
def gray_decode(n):
    m = n >> 1
    while m:
        n ^= m
        m >>= 1
    return n


async def run_test(dut):

    tb = TB(dut)
    dut.enable.value = 0

    clk = Clock(dut.clk, 8, units="ns")  # Create a 8ns period clock on port clk
    cocotb.start_soon(clk.start())  # Start the clock

    await tb.reset()

    await FallingEdge(dut.clk)
    dut.enable.value = 1

    for _ in range(3):
        for i in range(124993):
            assert gray_encode(i) == dut.cnt.value
            await FallingEdge(dut.clk)

    await ClockCycles(dut.clk, 10)


if cocotb.SIM_NAME:
    factory = TestFactory(run_test)
    factory.generate_tests()
