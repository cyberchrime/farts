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

from cocotbext.axi import AxiLiteMaster, AxiLiteBus


class TB:
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 6, units="ns").start())

        self.axil_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axil"), dut.clk, dut.rst)

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


# helper functions
def to_start_busy(val):
    return val << 28

def start_busy_from_reg(val):
    return (val >> 28) & 0x1

def to_op(val):
    return val << 26

def op_from_reg(val):
    return (val >> 26) & 0x3

def to_reg_adr(val):
    return val << 16

def reg_adr_from_reg(val):
    return (val >> 16) & 0x1f

def to_phy_adr(val):
    return val << 21

def phy_adr_from_reg(val):
    return (val >> 21) & 0x1f

def to_wdata(val):
    return val << 0

def wdata_from_reg(val):
    return (val >> 0) & 0xffff


MDIO_READ = to_op(0x2)
MDIO_WRITE = to_op(0x1)
MDIO_START_BUSY = 1

async def run_test(dut):
    tb = TB(dut)

    clock = Clock(dut.clk, 8, units="ns")  # Create a 8ns period clock on port clk
    cocotb.start_soon(clock.start())  # Start the clock

    for address in [0, 4]:
        dut.mdio_ready.value = 0
        dut.mdio_rdata.value = 0
        dut.mdio_rdata_valid.value = 0


        await tb.reset()

        mdio_wdata = to_wdata(0x23)
        mdio_op = MDIO_WRITE
        mdio_reg_adr = to_reg_adr(0x19)
        mdio_phy_adr = to_phy_adr(0x10)
        mdio_start_busy = to_start_busy(MDIO_START_BUSY)

        wdata = mdio_wdata | mdio_op | mdio_reg_adr | mdio_phy_adr | mdio_start_busy
        await tb.axil_master.write_dword(address, wdata)

        while True:
            rresp = await tb.axil_master.read(address, 4)
            rresp_data = int.from_bytes(rresp.data, 'little', signed=False)
            if not start_busy_from_reg(rresp_data):
                break



if cocotb.SIM_NAME:
    factory = TestFactory(run_test)
    factory.generate_tests()