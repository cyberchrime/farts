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

async def run_test_interrupt(dut):
    tb = TB(dut)

    clock = Clock(dut.clk, 8, units="ns")  # Create a 8ns period clock on port clk
    cocotb.start_soon(clock.start())  # Start the clock

    await tb.reset()

    dut.m_axis_write_desc_ready.value = 0


    wdata = 0x1
    wdata = (wdata).to_bytes(4, byteorder='little')
    await tb.axil_master.write(0x0008, wdata)

    wdata = 0x12345678
    wdata = (wdata).to_bytes(4, byteorder='little')
    await tb.axil_master.write(0x0000, wdata)

    rresp = await tb.axil_master.read(0x0, 4)
    rresp_data = rresp.data
    rresp_expected = wdata
    assert rresp_data == rresp_expected, f"Read data differs from written data: rresp={rresp_data} != wdata={rresp_expected}"

    assert not dut.m_axis_write_desc_valid.value, "DMA descriptor should NOT be asserted before WRITE to length register"

    wdata = 0xffffffff
    wdata = (wdata).to_bytes(4, byteorder='big')
    await tb.axil_master.write(0x0004, wdata)

    rresp = await tb.axil_master.read(0x4, 4)
    rresp_data = int.from_bytes(rresp.data, byteorder='little')
    rresp_expected = int.from_bytes(wdata, byteorder='little')
    rresp_expected &= 0xfff
    assert rresp_data == rresp_expected, f"Read data differs from written data: rresp={rresp_data} != wdata={rresp_expected}"

    assert dut.m_axis_write_desc_valid.value, "DMA descriptor should be asserted after WRITE to length register"


    await RisingEdge(dut.clk)
    dut.m_axis_write_desc_ready.value = 1
    assert dut.m_axis_write_desc_valid.value, "DMA descriptor should stay asserted till next edge after TREADY was asserted"
    await RisingEdge(dut.clk)
    dut.m_axis_write_desc_ready.value = 0
    assert dut.m_axis_write_desc_valid.value, "DMA descriptor should be low once TREADY was asserted"

    wdata = 0xdeadbeef
    wdata = (wdata).to_bytes(4, byteorder='big')
    await tb.axil_master.write(0x0004, wdata)

    dut.m_axis_write_desc_status_valid.value = 1
    await RisingEdge(dut.clk)
    dut.m_axis_write_desc_status_valid.value = 0
    await RisingEdge(dut.clk)


    rresp = await tb.axil_master.read(0x4, 4)
    rresp_data = int.from_bytes(rresp.data, byteorder='little')
    rresp_expected = int.from_bytes(wdata, byteorder='little')
    rresp_expected &= 0xfff
    assert rresp_data == rresp_expected, f"Read data differs from written data: rresp={rresp_data} != wdata={rresp_expected}"

    assert dut.m_axis_write_desc_valid.value, "DMA descriptor should be asserted after WRITE to length register"

    await RisingEdge(dut.clk)
    dut.m_axis_write_desc_ready.value = 1
    assert dut.m_axis_write_desc_valid.value, "DMA descriptor should stay asserted till next edge after TREADY was asserted"
    await RisingEdge(dut.clk)
    dut.m_axis_write_desc_ready.value = 0
    assert dut.m_axis_write_desc_valid.value, "DMA descriptor should be low once TREADY was asserted"


    # TODO: Validate whether descriptor stays unchanged on further writes

async def run_test(dut):
    tb = TB(dut)

    clock = Clock(dut.clk, 8, units="ns")  # Create a 8ns period clock on port clk
    cocotb.start_soon(clock.start())  # Start the clock

    await tb.reset()

    dut.m_axis_write_desc_ready.value = 0

    wdata = 0x12345678
    wdata = (wdata).to_bytes(4, byteorder='little')
    await tb.axil_master.write(0x0000, wdata)

    rresp = await tb.axil_master.read(0x0, 4)
    rresp_data = rresp.data
    rresp_expected = wdata
    assert rresp_data == rresp_expected, f"Read data differs from written data: rresp={rresp_data} != wdata={rresp_expected}"

    assert not dut.m_axis_write_desc_valid.value, "DMA descriptor should NOT be asserted before WRITE to length register"

    wdata = 0xffffffff
    wdata = (wdata).to_bytes(4, byteorder='big')
    await tb.axil_master.write(0x0004, wdata)

    rresp = await tb.axil_master.read(0x4, 4)
    rresp_data = int.from_bytes(rresp.data, byteorder='little')
    rresp_expected = int.from_bytes(wdata, byteorder='little')
    rresp_expected &= 0xfff
    assert rresp_data == rresp_expected, f"Read data differs from written data: rresp={rresp_data} != wdata={rresp_expected}"

    assert dut.m_axis_write_desc_valid.value, "DMA descriptor should be asserted after WRITE to length register"


    await RisingEdge(dut.clk)
    dut.m_axis_write_desc_ready.value = 1
    assert dut.m_axis_write_desc_valid.value, "DMA descriptor should stay asserted till next edge after TREADY was asserted"
    await RisingEdge(dut.clk)
    dut.m_axis_write_desc_ready.value = 0
    assert dut.m_axis_write_desc_valid.value, "DMA descriptor should be low once TREADY was asserted"

    wdata = 0xdeadbeef
    wdata = (wdata).to_bytes(4, byteorder='big')
    await tb.axil_master.write(0x0004, wdata)

    dut.m_axis_write_desc_status_valid.value = 1
    await RisingEdge(dut.clk)
    dut.m_axis_write_desc_status_valid.value = 0
    await RisingEdge(dut.clk)


    rresp = await tb.axil_master.read(0x4, 4)
    rresp_data = int.from_bytes(rresp.data, byteorder='little')
    rresp_expected = int.from_bytes(wdata, byteorder='little')
    rresp_expected &= 0xfff
    assert rresp_data == rresp_expected, f"Read data differs from written data: rresp={rresp_data} != wdata={rresp_expected}"

    assert dut.m_axis_write_desc_valid.value, "DMA descriptor should be asserted after WRITE to length register"

    await RisingEdge(dut.clk)
    dut.m_axis_write_desc_ready.value = 1
    assert dut.m_axis_write_desc_valid.value, "DMA descriptor should stay asserted till next edge after TREADY was asserted"
    await RisingEdge(dut.clk)
    dut.m_axis_write_desc_ready.value = 0
    assert dut.m_axis_write_desc_valid.value, "DMA descriptor should be low once TREADY was asserted"


    # TODO: Validate whether descriptor stays unchanged on further writes



if cocotb.SIM_NAME:
    factory = TestFactory([run_test_interrupt, run_test])
    factory.generate_tests()