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

        cocotb.start_soon(Clock(dut.clk, 7, units="ns").start())

        self.axis_source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), dut.clk, dut.rst, byte_lanes=8)
        self.axis_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.clk, dut.rst, byte_lanes=8)

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

    tb.axis_sink.pause = True
    tb.s_axis_dma_desc_addr.value = 0

    await tb.reset()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    dma_desc_addr_raw = 0x123456789abcdef
    dma_desc_length_raw = 123456789

    dma_desc_addr_big = (dma_desc_addr_raw).to_bytes(8, byteorder='little')
    dma_desc_length_big = (dma_desc_length_raw).to_bytes(4, byteorder='little')

    payload = dma_desc_addr_big + dma_desc_length_big + b'\0\0\0\0'
    await tb.axis_source.send(payload)
    await tb.axis_source.wait()

    await RisingEdge(dut.clk)

    assert dma_desc_addr_raw & 0xffffffff == tb.dut.dma_desc_addr.value.integer
    assert dma_desc_length_raw & 0xffff == tb.dut.dma_desc_length.value.integer

    tb.axis_sink.pause = False

    while True:
        if dut.m_axis_tlast.value:
            tb.axis_sink.pause = True
            break

        await FallingEdge(dut.clk)

    frame = await tb.axis_sink.recv()
    await FallingEdge(dut.clk)

    assert frame.tdata == payload

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


    dma_desc_addr_raw = 0xdeadbeefdeadbeef
    dma_desc_length_raw = 987654321

    dma_desc_addr_big = (dma_desc_addr_raw).to_bytes(8, byteorder='little')
    dma_desc_length_big = (dma_desc_length_raw).to_bytes(4, byteorder='little')

    payload = dma_desc_addr_big + dma_desc_length_big + b'\0\0\0\x01'
    await tb.axis_source.send(payload)
    await tb.axis_source.wait()

    await RisingEdge(dut.clk)

    assert dma_desc_addr_raw & 0xffffffff == tb.dut.dma_desc_addr.value.integer
    assert dma_desc_length_raw & 0xffff == tb.dut.dma_desc_length.value.integer

    tb.axis_sink.pause = False

    while True:
        if dut.m_axis_tlast.value:
            tb.axis_sink.pause = True
            break

        await FallingEdge(dut.clk)

    frame = await tb.axis_sink.recv()
    await FallingEdge(dut.clk)

    assert frame.tdata == payload

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


    dma_desc_addr_raw = 0xbeebbeebbeebbeeb
    dma_desc_length_raw = 4242424242

    dma_desc_addr_big = (dma_desc_addr_raw).to_bytes(8, byteorder='little')
    dma_desc_length_big = (dma_desc_length_raw).to_bytes(4, byteorder='little')

    payload = dma_desc_addr_big + dma_desc_length_big + b'\0\0\0\0'
    await tb.axis_source.send(payload)
    await tb.axis_source.wait()

    await RisingEdge(dut.clk)

    assert dma_desc_addr_raw & 0xffffffff == tb.dut.dma_desc_addr.value.integer
    assert dma_desc_length_raw & 0xffff == tb.dut.dma_desc_length.value.integer

    tb.axis_sink.pause = False

    dut.s_axis_dma_desc_length.value = 123
    dut.s_axis_dma_desc_valid.value = 1

    await RisingEdge(dut.clk)

    dut.s_axis_dma_desc_length.value = 123
    dut.s_axis_dma_desc_valid.value = 0

    await RisingEdge(dut.clk)

    dut.s_axis_dma_desc_length.value = 456

    while True:
        if dut.m_axis_tlast.value:
            tb.axis_sink.pause = True
            break

        await FallingEdge(dut.clk)

    frame = await tb.axis_sink.recv()
    await FallingEdge(dut.clk)


    dma_desc_length_big = (123).to_bytes(4, byteorder='little')
    assert frame.tdata == dma_desc_addr_big + dma_desc_length_big + b'\0\0\0\0'

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


if cocotb.SIM_NAME:
    factory = TestFactory(run_test)
    factory.generate_tests()