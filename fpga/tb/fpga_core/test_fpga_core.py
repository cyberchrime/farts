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

from cgi import test
import itertools
import logging
import os
import random

import cocotb_test.simulator
import pytest

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Event, Timer
from cocotb.regression import TestFactory
from cocotb.result import SimTimeoutError

from cocotbext.axi import AxiWriteBus, AxiRamWrite, AxiLiteMaster, AxiLiteBus
from cocotbext.eth import GmiiFrame, RgmiiSource

DESC_SIZE = 16 # in bytes
DESC_RING_ADDR = 0x1000
BUFFER_ADDR = 0x40000

DMA_ADR_ID = 0
DMA_LENGTH_ID = 4
DMA_CTRL_ID = 8
DMA_STATUS_ID = 12

MAC_CTRL_ID = 0
MAC_STATUS_ID = 4

AXI_PERIOD = 6
PERIOD_UNITS = 'ns'

DESC_ADDR_WIDTH = 12
DESC_RAM_SIZE = 2**DESC_ADDR_WIDTH
DESC_COUNT = int(DESC_RAM_SIZE/DESC_SIZE)

class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.phy1_rgmii_rx_clk, 8, units=PERIOD_UNITS).start())
        cocotb.start_soon(Clock(dut.phy2_rgmii_rx_clk, 8, units=PERIOD_UNITS).start())
        cocotb.start_soon(Clock(dut.axi_clk, AXI_PERIOD, units=PERIOD_UNITS).start())
        cocotb.start_soon(Clock(dut.counter_clk, 5, units=PERIOD_UNITS).start())

        # RGMII interfaces
        self.rgmii1_source = RgmiiSource(dut.phy1_rgmii_rxd, dut.phy1_rgmii_rx_ctl, dut.phy1_rgmii_rx_clk, dut.axi_rst)
        self.rgmii2_source = RgmiiSource(dut.phy2_rgmii_rxd, dut.phy2_rgmii_rx_ctl, dut.phy2_rgmii_rx_clk, dut.axi_rst)

        # AXI interface
        self.axi_ram = AxiRamWrite(AxiWriteBus.from_prefix(dut, "m_axi"), dut.axi_clk, dut.axi_rst, size=2**20)

        # AXI Lite Master
        self.axil_mac_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axil_mac"), dut.axi_clk, dut.axi_rst)
        self.axil_dma_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axil_dma"), dut.axi_clk, dut.axi_rst)
        self.axil_desc_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axil_dma_desc"), dut.axi_clk, dut.axi_rst)

    def set_idle_generator(self, generator=None):
        if generator:
            self.write_data_source.set_pause_generator(generator())
            self.axi_ram.b_channel.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.axi_ram.w_channel.set_pause_generator(generator())

    async def cycle_reset(self):
        self.dut.axi_rst.setimmediatevalue(0)
        self.dut.counter_rst.setimmediatevalue(0)
        await RisingEdge(self.dut.axi_clk)
        await RisingEdge(self.dut.axi_clk)
        self.dut.axi_rst.value = 1
        self.dut.counter_rst.value = 1
        await RisingEdge(self.dut.axi_clk)
        await RisingEdge(self.dut.axi_clk)
        self.dut.axi_rst.value = 0
        self.dut.counter_rst.value = 0
        await RisingEdge(self.dut.axi_clk)
        await RisingEdge(self.dut.axi_clk)

    async def write_descriptor_ring(self):
        r = range(0, 512*1024, 2048)
        r = random.sample(r, DESC_COUNT)

        for i in range(DESC_COUNT):
            offset = r[i]

            dma_desc_addr_raw = offset
            dma_desc_length_raw = 2048
            dma_desc_flags_raw = 0x1 # set empty flag

            dma_desc_addr_big = (dma_desc_addr_raw).to_bytes(8, byteorder='little')
            dma_desc_length_big = (dma_desc_length_raw).to_bytes(4, byteorder='little')
            dma_desc_flags_big = (dma_desc_flags_raw).to_bytes(4, byteorder='little')

            dma_desc = dma_desc_addr_big + dma_desc_length_big + dma_desc_flags_big

            await self.axil_desc_master.write(DESC_SIZE*i, dma_desc)


async def run_test_continuous(dut):
    tb = TB(dut)

    await tb.cycle_reset()
    await tb.write_descriptor_ring()

    test_frames = [incrementing_payload(x) for x in range(64, 1500)]

    wdata = DESC_RING_ADDR
    await tb.axil_dma_master.write_dword(DMA_ADR_ID, wdata)

    wdata = 0x5 # enable DMA and IRQ and
    await tb.axil_dma_master.write_dword(DMA_CTRL_ID, wdata)

    wdata = 0x1 # enable MAC
    await tb.axil_mac_master.write_dword(MAC_CTRL_ID, wdata)

    for test_data in test_frames:
        test_frame = GmiiFrame.from_payload(test_data)
        tb.rgmii1_source.send_nowait(test_frame)
        tb.rgmii2_source.send_nowait(test_frame)

    i = 0
    expected_rgmii1_length = 84
    expected_rgmii2_length = 84

    while True:
        try:
            await cocotb.triggers.with_timeout(RisingEdge(tb.dut.dma_irq), AXI_PERIOD * 10000, timeout_unit=PERIOD_UNITS)
        except SimTimeoutError:
            if tb.rgmii2_source.empty() and tb.rgmii2_source.empty() and expected_rgmii1_length == 1516 and expected_rgmii2_length == 1516:
                break
            elif tb.dut.dma_irq.value:
                pass
            else:
                assert False, "Did not receive an interrupt after an appropriate time"

        await Timer(4, "us") # wait before running "interrupt handler"
        await tb.axil_dma_master.write_dword(DMA_STATUS_ID, 0x2) # deassert IRQ

        while True:
            dma_desc_flags = await tb.axil_desc_master.read_dword((DESC_SIZE*i) + 12)
            dma_desc_addr = await tb.axil_desc_master.read_qword((DESC_SIZE*i))
            dma_desc_len = await tb.axil_desc_master.read_dword((DESC_SIZE*i) + 8)
            dma_desc_empty = dma_desc_flags & 0x1

            if dma_desc_empty:
                break

            ram_content = tb.axi_ram.read(dma_desc_addr, dma_desc_len)

            print("expected_length1", expected_rgmii1_length)
            print("expected_length2", expected_rgmii2_length)

            if (expected_rgmii1_length == dma_desc_len):
                expected_length = expected_rgmii1_length
                expected_rgmii1_length += 1
            elif (expected_rgmii2_length == dma_desc_len):
                expected_length = expected_rgmii2_length
                expected_rgmii2_length += 1
            else:

                assert False, f"Unexpected length {dma_desc_len};" \
                    f" expected {expected_rgmii1_length} or {expected_rgmii2_length}" \
                    f" at descriptor {i}"

            test_frame = test_frames[expected_length-84]
            assert ram_content[16:-4] == test_frame, "Wrong payload"

            tb.axi_ram.write(dma_desc_addr, b"\xaa" * (dma_desc_len + 16))

            await tb.axil_desc_master.write_dword((DESC_SIZE*i) + 8, 2048)
            await tb.axil_desc_master.write_dword((DESC_SIZE*i) + 12, dma_desc_flags | 0x1) # set empty flag

            i = 0 if i == DESC_COUNT-1 else i+1


def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))

def cycle_pause():
    return itertools.cycle((10 * [1]) + [0])


if cocotb.SIM_NAME:
    for test in [run_test_continuous]:
        factory = TestFactory(test)
        factory.generate_tests()
