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

        cocotb.start_soon(Clock(dut.clk, 8, units="ns").start())

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

    dut.mdio_ready.value = 0
    dut.mdio_rdata.value = 0
    dut.mdio_rdata_valid.value = 0
    dut.mdio_busy.value = 0


    await tb.reset()

    mdio_wdata = to_wdata(0x23)
    mdio_op = MDIO_WRITE
    mdio_reg_adr = to_reg_adr(0x19)
    mdio_phy_adr = to_phy_adr(0x10)
    mdio_start_busy = to_start_busy(MDIO_START_BUSY)

    wdata = mdio_wdata | mdio_op | mdio_reg_adr | mdio_phy_adr | mdio_start_busy
    wdata = (wdata).to_bytes(4, byteorder='little')
    await tb.axil_master.write(0x0000, wdata)

    dut.mdio_busy.value = 1

    for _ in range(10):
        rresp = await tb.axil_master.read(0x0, 4)
        rresp_data = int.from_bytes(rresp.data, 'little', signed=False)
        assert start_busy_from_reg(rresp_data), f"Did NOT YET expect the operation to complete"


    assert dut.mdio_wdata.value == wdata_from_reg(mdio_wdata)
    assert dut.mdio_op.value == op_from_reg(mdio_op)
    assert dut.mdio_reg_adr.value == reg_adr_from_reg(mdio_reg_adr)
    assert dut.mdio_phy_adr.value == phy_adr_from_reg(mdio_phy_adr)
    assert dut.mdio_valid.value == start_busy_from_reg(mdio_start_busy)

    # trigger handshake of MDIO interface
    await RisingEdge(dut.clk)
    dut.mdio_ready.value = 1
    await RisingEdge(dut.clk)
    dut.mdio_ready.value = 0

    for _ in range(5):
        rresp = await tb.axil_master.read(0x0, 4)
        rresp_data = int.from_bytes(rresp.data, 'little', signed=False)
        assert start_busy_from_reg(rresp_data), f"Did NOT YET expect the operation to complete"

    dut.mdio_busy.value = 0
    rresp = await tb.axil_master.read(0x0, 4)
    rresp_data = int.from_bytes(rresp.data, 'little', signed=False)

    assert not start_busy_from_reg(rresp_data), f"Did expect the operation to complete"


    mdio_op = MDIO_READ
    mdio_reg_adr = to_reg_adr(0x17)
    mdio_phy_adr = to_phy_adr(0x5)
    mdio_start_busy = to_start_busy(MDIO_START_BUSY)

    wdata = mdio_wdata | mdio_op | mdio_reg_adr | mdio_phy_adr | mdio_start_busy
    wdata = (wdata).to_bytes(4, byteorder='little')
    dut.mdio_busy.value = 1

    await tb.axil_master.write(0x0000, wdata)
    for _ in range(10):
        rresp = await tb.axil_master.read(0x0, 4)
        rresp_data = int.from_bytes(rresp.data, 'little', signed=False)
        assert start_busy_from_reg(rresp_data), f"Did NOT YET expect the operation to complete"

    assert dut.mdio_op.value == op_from_reg(mdio_op)
    assert dut.mdio_reg_adr.value == reg_adr_from_reg(mdio_reg_adr)
    assert dut.mdio_phy_adr.value == phy_adr_from_reg(mdio_phy_adr)
    assert dut.mdio_valid.value == 1

    # trigger handshake of MDIO interface
    await RisingEdge(dut.clk)
    dut.mdio_ready.value = 1
    await RisingEdge(dut.clk)
    dut.mdio_ready.value = 0

    for _ in range(5):
        rresp = await tb.axil_master.read(0x0, 4)
        rresp_data = int.from_bytes(rresp.data, 'little', signed=False)
        assert start_busy_from_reg(rresp_data), f"Did NOT YET expect the operation to complete"

    assert dut.mdio_rdata_ready.value

    await RisingEdge(dut.clk)
    dut.mdio_rdata_valid.value = 1
    dut.mdio_rdata.value = 0x42

    while True:
        if dut.mdio_rdata_ready.value == 1:
            dut.mdio_busy.value = 0
            break
        else:
            await RisingEdge(dut.clk)

    rresp = await tb.axil_master.read(0x0, 4)
    rresp_data = int.from_bytes(rresp.data, 'little', signed=False)

    assert not start_busy_from_reg(rresp_data & 0x1), f"Did expect the operation to complete"


if cocotb.SIM_NAME:
    factory = TestFactory(run_test)
    factory.generate_tests()