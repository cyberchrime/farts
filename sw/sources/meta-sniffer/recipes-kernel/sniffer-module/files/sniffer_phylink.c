// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * Driver for the Real-Time Sniffer aRTS
 *
 * 2023 (c) Chris H. Meyer
 */

#include <linux/phylink.h>
#include <linux/phy.h>
#include <linux/of_net.h>

#include "sniffer.h"


static void sniffer_mac_link_down(struct phylink_config *config,
				  unsigned int mode,
				  phy_interface_t interface)
{
	/* TODO: reenable more link speeds if applicable */
}

static void sniffer_mac_link_up(struct phylink_config *config,
				struct phy_device *phy,
				unsigned int mode, phy_interface_t interface,
				int speed, int duplex,
				bool tx_pause, bool rx_pause)
{
	struct sniffer_local *lp = config->dev->driver_data;
	u32 mac_conf_reg;
	void __iomem *reg_adr;

	reg_adr = lp->regs + SNIFFER_MAC_CTRL_OFFSET;

	mac_conf_reg = sniffer_ior(reg_adr);

	switch (speed) {
	case SPEED_1000:
		mac_conf_reg &= ~SNIFFER_MAC_CTRL_MII_MASK;
		break;
	case SPEED_100:
	case SPEED_10:
		mac_conf_reg |= SNIFFER_MAC_CTRL_MII_MASK;
		break;
	default:
		dev_err(config->dev,
			"Speed other than 10, 100 or 1Gbps is not supported\n");
		break;
	}

	sniffer_iow(reg_adr, mac_conf_reg);
}

static void sniffer_mac_config(struct phylink_config *config, unsigned int mode,
			       const struct phylink_link_state *state)
{
	// TODO: is there something to do?
}

static int sniffer_mac_prepare(struct phylink_config *config, unsigned int mode,
			       phy_interface_t iface)
{
	// TODO: is there something to do?
	return 0;
}

static void sniffer_validate(struct phylink_config *config,
			     unsigned long *supported,
			     struct phylink_link_state *state)
{
	__ETHTOOL_DECLARE_LINK_MODE_MASK(mask) = { 0, };

	phylink_set(mask, Autoneg); // TODO: is this appropriate?
	phylink_set_port_modes(mask); // TODO: is this appropriate?
	phylink_set(mask, Asym_Pause); // TODO: is this appropriate?
	phylink_set(mask, Pause); // TODO: is this appropriate?

	switch (state->interface) {
	case PHY_INTERFACE_MODE_RGMII:
	case PHY_INTERFACE_MODE_RGMII_ID:
	case PHY_INTERFACE_MODE_RGMII_RXID:
	case PHY_INTERFACE_MODE_RGMII_TXID:
		phylink_set(mask, 1000baseT_Full);
		phylink_set(mask, 1000baseT_Half);
		fallthrough;
	case PHY_INTERFACE_MODE_MII:
		phylink_set(mask, 100baseT_Full);
		phylink_set(mask, 100baseT_Half);
		phylink_set(mask, 10baseT_Full);
		phylink_set(mask, 10baseT_Half);
		fallthrough;
	default:
		break;
	}

	bitmap_and(supported, supported, mask,
		   __ETHTOOL_LINK_MODE_MASK_NBITS);
	bitmap_and(state->advertising, state->advertising, mask,
		   __ETHTOOL_LINK_MODE_MASK_NBITS);
}

static void sniffer_mac_pcs_get_state(struct phylink_config *config,
				      struct phylink_link_state *state)
{
	// TODO: is there something to do?
}

static void sniffer_mac_an_restart(struct phylink_config *config)
{
	// TODO: is there something to do?
}


static const struct phylink_mac_ops sniffer_phylink_ops = {
	.validate = sniffer_validate,
	.mac_pcs_get_state = sniffer_mac_pcs_get_state,
	.mac_an_restart = sniffer_mac_an_restart,
	.mac_prepare = sniffer_mac_prepare,
	.mac_config = sniffer_mac_config,
	.mac_link_down = sniffer_mac_link_down,
	.mac_link_up = sniffer_mac_link_up,
};/* based on drivers/net/ethernet/cadence/macb_main.c */

int sniffer_setup_phylink(struct sniffer_local *lp)
{
	int i;
	int ret;
	phy_interface_t interface;

	lp->speed = 100;
	lp->powerdown = 0;

	lp->phylink_config.dev = lp->dev;
	lp->phylink_config.type = PHYLINK_DEV;
	lp->phylink_config.pcs_poll = true;

	// TODO: is this required?
	ret = of_get_phy_mode(lp->dev->of_node, &interface);
	if (ret)
		/* not found in DT, MII by default */
		interface = PHY_INTERFACE_MODE_RGMII_TXID;

	for (i = 0; i < SNIFFER_MDIO_BUS_COUNT; i++) {
		struct phy_device *phydev;

		dev_dbg(lp->dev, "Creating  %d. phylink...\n", i);
		lp->phylink[i] = phylink_create(&lp->phylink_config, lp->dev->fwnode,
                                    interface, &sniffer_phylink_ops);

		phydev = phy_find_first(lp->mii_bus[i]);
		if (!phydev) {
			dev_err(lp->dev, "no PHY found on bus (%d)\n", i);
			return -ENXIO;
		}

		dev_dbg(lp->dev, "Connecting PHY to %d. phylink...\n", i);
		ret = phylink_connect_phy(lp->phylink[i], phydev);
		lp->phydev[i] = phydev;

		if (ret) {
			dev_err(lp->dev, "Could not attach PHY (%d)\n", ret);
			return ret;
		}

		dev_dbg(lp->dev, "Starting %d. phylink...\n", i);
		phylink_start(lp->phylink[i]);
	}

	ret = set_speed(lp, lp->speed);

	if (ret) {
		dev_err(lp->dev, "Illegal speed");
		return ret;
	}

	return 0;
};
