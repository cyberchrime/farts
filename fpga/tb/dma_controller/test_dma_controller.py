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
from cocotb.result import SimTimeoutError

from cocotbext.axi import AxiLiteMaster, AxiLiteBus, AxiRamWrite, AxiWriteBus, AxiStreamSource, AxiStreamBus

import random

DESC_SIZE = 16 # in bytes
DESC_RING_ADDR = 0x1000
BUFFER_ADDR = 0x40000

DMA_ADR_ID = 0
DMA_LENGTH_ID = 4
DMA_CTRL_ID = 8
DMA_STATUS_ID = 12

PERIOD = 7
PERIOD_UNITS = 'ns'

class TB:
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, PERIOD, units=PERIOD_UNITS).start())

        self.axil_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axil"), dut.clk, dut.rst)
        self.axil_desc_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axil_desc"), dut.clk, dut.rst)
        self.axi_ram = AxiRamWrite(AxiWriteBus.from_prefix(dut, "m_axi"), dut.clk, dut.rst, size=2**20)
        self.axis_source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), dut.clk, dut.rst)

    def set_idle_generator(self, generator=None):
        if generator:
            self.axis_source.set_pause_generator(generator())
            self.axi_ram.b_channel.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.axi_ram.w_channel.set_pause_generator(generator())


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

    async def write_descriptor_ring(self):
        random.seed(0)

        for i in range(256):
            offset = random.randrange(0, 512*1024, 2048)

            dma_desc_addr_raw = BUFFER_ADDR + offset
            dma_desc_length_raw = 2048
            dma_desc_flags_raw = 0x1 # set empty flag
            dma_desc_flags_raw |= 0x2 if i == 127 else 0x0

            dma_desc_addr_big = (dma_desc_addr_raw).to_bytes(8, byteorder='little')
            dma_desc_length_big = (dma_desc_length_raw).to_bytes(4, byteorder='little')
            dma_desc_flags_big = (dma_desc_flags_raw).to_bytes(4, byteorder='little')

            dma_desc = dma_desc_addr_big + dma_desc_length_big + dma_desc_flags_big

            await self.axil_desc_master.write(DESC_SIZE*i, dma_desc)


async def run_incr_test(dut, idle_inserter=None, backpressure_inserter=None):
    tb = TB(dut)

    await tb.reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    await tb.write_descriptor_ring()

    offset_generator = random.Random(0)
    bool_generator = random.Random(0)

    payload_lengths = list(range(64, 120))
    payloads = [incrementing_payload(length) for length in payload_lengths]
    for i in range(len(payloads)):
        payload = payloads[i]
        offset = offset_generator.randrange(0, 512*1024, 2048)

        tb.axi_ram.write(BUFFER_ADDR, b"\xaa" * (1024*512))

        wdata = 0x1 | 0x4 # enable DMA and IRQ
        await tb.axil_master.write_dword(DMA_CTRL_ID, wdata)

        await tb.axis_source.send(payload)

        if not tb.dut.irq.value:
            try:
                await cocotb.triggers.with_timeout(RisingEdge(tb.dut.irq), PERIOD * 2000, timeout_unit=PERIOD_UNITS)
                if (bool(bool_generator.randint(0, 1))): # randomly disable IRQ
                    reg = await tb.axil_master.read_dword(DMA_STATUS_ID)
                    assert reg & 0x2, "Interrupt is not set pending in STATUS register"

                    await tb.axil_master.write_dword(DMA_STATUS_ID, reg)

                    assert not tb.dut.irq.value, "Interrupt is still pending after resetting in STATUS register"
            except SimTimeoutError:
                assert False, "Did not receive an interrupt after an appropriate time"
        else:
            try:
                await cocotb.triggers.with_timeout(RisingEdge(tb.dut.axis_write_desc_status_valid), PERIOD * 2000, timeout_unit=PERIOD_UNITS)
            except SimTimeoutError:
                assert False, "The transmission was not completed after an appropriate time"


        descriptor_addr = DESC_SIZE*i
        descriptor_buffer_addr = await tb.axil_desc_master.read_qword(descriptor_addr)
        descriptor_length = await tb.axil_desc_master.read_dword(descriptor_addr + 8)
        descriptor_empty = await tb.axil_desc_master.read_byte(descriptor_addr + 12)

        assert descriptor_buffer_addr == BUFFER_ADDR + offset, "Buffer address was modified"
        assert descriptor_length == len(payload), "Buffer length does NOT match count of transferred bytes"
        assert not (descriptor_empty & 0x1), "Empty flag is still set"

        ram_content = tb.axi_ram.read(BUFFER_ADDR + offset, len(payload))
        assert ram_content == payload, f"RAM differs at address {hex(BUFFER_ADDR + offset)}"

async def run_soft_reset_test(dut, idle_inserter=None, backpressure_inserter=None):
    tb = TB(dut)

    await tb.reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    payloads = [incrementing_payload(64)] * 3

    for _ in range(2):
        await tb.write_descriptor_ring()
        wdata = 0x7 # enable DMA and IRQ and do soft reset
        await tb.axil_master.write_dword(DMA_CTRL_ID, wdata)

        offset_generator = random.Random(0)

        for i in range(len(payloads)):
            payload = payloads[i]
            offset = offset_generator.randrange(0, 512*1024, 2048)

            tb.axi_ram.write(BUFFER_ADDR, b"\xaa" * (1024*512))


            await tb.axis_source.send(payload)

            try:
                await cocotb.triggers.with_timeout(RisingEdge(tb.dut.irq), PERIOD * 2000, timeout_unit=PERIOD_UNITS)
                reg = await tb.axil_master.read_dword(DMA_STATUS_ID)
                assert reg & 0x2, "Interrupt is not set pending in STATUS register"
                await tb.axil_master.write_dword(DMA_STATUS_ID, reg)
            except SimTimeoutError:
                assert False, "Did not receive an interrupt after an appropriate time"

            descriptor_addr = DESC_SIZE*i
            descriptor_buffer_addr = await tb.axil_desc_master.read_qword(descriptor_addr)
            descriptor_length = await tb.axil_desc_master.read_dword(descriptor_addr + 8)
            descriptor_empty = await tb.axil_desc_master.read_byte(descriptor_addr + 12)

            assert descriptor_buffer_addr == BUFFER_ADDR + offset, "Buffer address was modified"
            assert descriptor_length == len(payload), "Buffer length does NOT match count of transferred bytes"
            assert not (descriptor_empty & 0x1), "Empty flag is still set"

            ram_content = tb.axi_ram.read(BUFFER_ADDR + offset, len(payload))
            assert ram_content == payload, f"RAM differs at address {hex(BUFFER_ADDR + offset)}"




def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))

def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])

if cocotb.SIM_NAME:
    for test in [run_soft_reset_test, run_incr_test]:
        factory = TestFactory(test)
        factory.add_option("idle_inserter", [None, cycle_pause])
        factory.add_option("backpressure_inserter", [None, cycle_pause])
        factory.generate_tests()