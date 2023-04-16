// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * Driver for the Real-Time Sniffer aRTS
 *
 * 2023 (c) Chris H. Meyer
 */

#include <linux/clk.h>
#include <linux/of_address.h>
#include <linux/of_mdio.h>
#include <linux/jiffies.h>
#include <linux/iopoll.h>

#include "sniffer.h"

static int sniffer_mdio_wait_read(struct sniffer_local *lp, off_t mdio_offset)
{
	int ret;
	u32 val;
	void __iomem *regs;

	regs = lp->regs + mdio_offset;

	ret = readx_poll_timeout(sniffer_ior, regs, val,
		!(val & SNIFFER_MDIO_READY_MASK), 1, 20000);

	if (ret < 0) {
		dev_warn(lp->dev, "%s: Waiting for ready signal returned %i\n", __func__, ret);
		return ret;
	} else {
		return (int) ((val & SNIFFER_MDIO_DATA_MASK) >> SNIFFER_MDIO_DATA_SHIFT);
	}
}

static int sniffer_mdio_wait_until_ready(struct sniffer_local *lp, off_t mdio_offset)
{
	u32 val;
	int ret;
	void __iomem *regs;

	regs = lp->regs + mdio_offset;

	ret = readx_poll_timeout(sniffer_ior, regs, val,
        !(val & SNIFFER_MDIO_READY_MASK), 1, 20000);

	dev_dbg(lp->dev, "%s: Waiting for ready signal returned %i\n", __func__, ret);

	return ret;
}

static int sniffer_mdio_offset_detect(struct mii_bus *bus)
{
	struct sniffer_local *lp = bus->priv;
	int i;
	unsigned int offset;

	// set default offset
	offset = SNIFFER_MDIO1_OFFSET;

	// TODO: implement the possibility to connect two PHYs to the same MDIO bus
	for (i = 0; i < SNIFFER_MDIO_BUS_COUNT; i++)
		if (bus == lp->mii_bus[i]) {
			if (i == 1)
				offset = SNIFFER_MDIO2_OFFSET;

			dev_dbg(lp->dev, "%s: using offset %x\n", __func__, offset);
			return offset;
		}

	dev_warn(lp->dev, "%s: Unknown mii_bus\n", __func__);
	return -EINVAL;
}

// TODO: adapt this function
static int sniffer_mdio_read(struct mii_bus *bus, int phy_id, int reg)
{
	int ret;
	off_t mdio_offset;
	struct sniffer_local *lp = bus->priv;

	ret = sniffer_mdio_offset_detect(bus);
	if (ret < 0)
		return ret;
	else
		mdio_offset = ret;

	dev_dbg(lp->dev, "lp=0x%08x, dev=0x%08x, Reading from %08x...\n", lp, lp->dev, lp->regs + mdio_offset);

	ret = sniffer_mdio_wait_until_ready(lp, mdio_offset);
	if (ret < 0)
		return ret;

	sniffer_iow(lp->regs + mdio_offset,
			(SNIFFER_MDIO_READY_MASK |
			(SNIFFER_MDIO_OP_READ << SNIFFER_MDIO_OP_SHIFT) |
			((phy_id << SNIFFER_MDIO_PHYADR_SHIFT) & SNIFFER_MDIO_PHYADR_MASK) |
			((reg << SNIFFER_MDIO_REGADR_SHIFT) & SNIFFER_MDIO_REGADR_MASK))
		);

	ret = sniffer_mdio_wait_read(lp, mdio_offset);
	if (ret < 0) {
		dev_warn(&bus->dev, "%s: Error %i\n", __func__, ret);
		return ret;
	}

	dev_dbg(lp->dev, "%s: Read value 0x%x\n", __func__, ret);

	return ret;
}


static int sniffer_mdio_write(struct mii_bus *bus, int phy_id, int reg, u16 val)
{
	int ret;
	off_t mdio_offset;
	struct sniffer_local *lp = bus->priv;

	ret = sniffer_mdio_offset_detect(bus);
	if (ret < 0)
		return ret;
	else
		mdio_offset = ret;

	dev_dbg(lp->dev, "lp=0x%08x, dev=0x%08x, Writing to %08x...\n", lp, lp->dev, lp->regs + mdio_offset);

	ret = sniffer_mdio_wait_read(lp, mdio_offset);
	if (ret < 0) {
		return ret;
	}

	sniffer_iow(lp->regs + mdio_offset,
			(SNIFFER_MDIO_READY_MASK |
			(SNIFFER_MDIO_OP_WRITE << SNIFFER_MDIO_OP_SHIFT) |
			((phy_id << SNIFFER_MDIO_PHYADR_SHIFT) & SNIFFER_MDIO_PHYADR_MASK) |
			((reg << SNIFFER_MDIO_REGADR_SHIFT) & SNIFFER_MDIO_REGADR_MASK) |
			(val << SNIFFER_MDIO_DATA_SHIFT))
		);

	ret = sniffer_mdio_wait_until_ready(lp, mdio_offset);
	if (ret < 0) {
		dev_warn(&bus->dev, "%s: Error %i\n", __func__, ret);
		return ret;
	}

	return 0;
}

int sniffer_mdio_setup(struct sniffer_local *lp)
{
	struct mii_bus *bus;
	int ret;
	int i, j;

	for (i = 0; i < SNIFFER_MDIO_BUS_COUNT; i++) {
		bus = mdiobus_alloc();
		if (!bus)
			return -ENOMEM;

		if (i == 0)
			snprintf(bus->id, MII_BUS_ID_SIZE, "sniffer-%.8lx",
				(unsigned long)lp->regs + SNIFFER_MDIO1_OFFSET);
		else
			snprintf(bus->id, MII_BUS_ID_SIZE, "sniffer-%.8lx",
				(unsigned long)lp->regs + SNIFFER_MDIO2_OFFSET);

		bus->priv = lp;
		bus->name = "A RealTime Sniffer MDIO";
		bus->read = sniffer_mdio_read;
		bus->write = sniffer_mdio_write;
		bus->parent = lp->dev;
		lp->mii_bus[i] = bus;

		dev_dbg(lp->dev, "Registering %i. MII Bus\n", i + 1);

		ret = mdiobus_register(bus);
		if (ret) {
			// free the current and all previously allocated mdio buses
			for (j = 0; j <= i; j++) {
				mdiobus_free(lp->mii_bus[i]);
				lp->mii_bus[j] = NULL;

				dev_dbg(lp->dev, "Error %i - freeing %i. MII Bus\n", ret, j + 1);
			}


			return ret;
		}
	}

	return 0;
}

void sniffer_mdio_teardown(struct sniffer_local *lp)
{
	int i;

	for (i = 0; i < SNIFFER_MDIO_BUS_COUNT; i++) {
		mdiobus_unregister(lp->mii_bus[i]);
		mdiobus_free(lp->mii_bus[i]);
		lp->mii_bus[i] = NULL;
	}
}
