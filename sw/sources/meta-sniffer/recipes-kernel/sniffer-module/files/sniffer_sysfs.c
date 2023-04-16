// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * Driver for the Real-Time Sniffer aRTS
 *
 * 2023 (c) Chris H. Meyer
 */

#include "sniffer.h"
#include <linux/phy.h>
#include <linux/ethtool.h>

static ssize_t sniffer_show_powerdown(struct device *dev, struct device_attribute *attr,
		char *buf)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);

	return sysfs_emit(buf, "%u\n", lp->powerdown);

}

static ssize_t sniffer_store_powerdown(struct device *dev, struct device_attribute *attr,
		const char *buf, size_t count)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	struct phy_device *phydev;
	bool powerdown;
	int ret;

	if (!mutex_trylock(&lp->running)) {
		dev_err(lp->dev,
			"Powerdown mode can be changed only when not running");
		return -EBUSY;
	}

	ret = kstrtobool(buf, &powerdown);
	if (ret) {
		return ret;
	}

	if (lp->powerdown != powerdown) {
		int i;
		for (i = 0; i < SNIFFER_MDIO_BUS_COUNT; i++) {
			phydev = lp->phydev[i];

			if (powerdown) {
				phy_suspend(phydev);
			} else {
				phy_resume(phydev);
			}
		}
	}

	mutex_unlock(&lp->running);

	lp->powerdown = powerdown;

	return count;

}

int set_speed(struct sniffer_local *lp, unsigned int speed)
{
	__ETHTOOL_DECLARE_LINK_MODE_MASK(mask) = { 0, };

	struct phy_device *phydev;
	int i;

	switch(speed) {
		case SPEED_10:
			linkmode_set_bit(ETHTOOL_LINK_MODE_10baseT_Full_BIT, mask);
			break;
		case SPEED_100:
			linkmode_set_bit(ETHTOOL_LINK_MODE_100baseT_Full_BIT, mask);
			break;
		case SPEED_1000:
			linkmode_set_bit(ETHTOOL_LINK_MODE_1000baseT_Full_BIT, mask);
			break;
		default:
			return -EINVAL;
			break;
	}

	for (i = 0; i < SNIFFER_MDIO_BUS_COUNT; i++) {
		phydev = lp->phydev[i];

		mutex_lock(&phydev->lock);

		phydev->speed = speed;
		linkmode_copy(phydev->advertising, mask);

		if (phy_is_started(phydev)) {
			phydev->state = PHY_UP;
			phy_trigger_machine(phydev);
			mutex_unlock(&phydev->lock);
		} else {
			mutex_unlock(&phydev->lock);
			phy_start_aneg(phydev);
		}
	}

	return 0;
}

static ssize_t sniffer_store_speed(struct device *dev, struct device_attribute *attr,
	       const char *buf, size_t count)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	unsigned int speed;
	int ret;

	if (&lp->running) {
		dev_err(lp->dev, "Speed can be changed only when not running");
		return -EBUSY;
	}

	ret = kstrtouint(buf, 0, &speed);
	if (ret) {
		return ret;
	}

	ret = set_speed(lp, speed);
	if (ret) {
		return ret;
	}

	lp->speed = speed;

	return count;
}

static ssize_t sniffer_show_speed(struct device *dev, struct device_attribute *attr,
		char *buf)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);

	return sysfs_emit(buf, "%u\n", lp->speed);
}

static ssize_t sniffer_show_mac1_start_frames(struct device *dev, struct device_attribute *attr,
                char *buf)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_MAC1_START_FRAME_OFFSET;
	u32 reg_content;

	reg_content = sniffer_ior(reg_adr);
	return sysfs_emit(buf, "%u\n", reg_content);
}

static ssize_t sniffer_store_mac1_start_frames(struct device *dev, struct device_attribute *attr,
                const char *buf, size_t count)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_MAC1_START_FRAME_OFFSET;
	u32 reg_content;
	int ret;

	ret = kstrtouint(buf, 0, &reg_content);
	if (ret) {
		return ret;
	}

	sniffer_iow(reg_adr, reg_content);
	return count;
}

static ssize_t sniffer_show_mac2_start_frames(struct device *dev, struct device_attribute *attr,
                char *buf)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_MAC2_START_FRAME_OFFSET;
	u32 reg_content;

	reg_content = sniffer_ior(reg_adr);
	return sysfs_emit(buf, "%u\n", reg_content);
}

static ssize_t sniffer_store_mac2_start_frames(struct device *dev, struct device_attribute *attr,
                const char *buf, size_t count)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_MAC2_START_FRAME_OFFSET;
	u32 reg_content;
	int ret;

	ret = kstrtouint(buf, 0, &reg_content);
	if (ret) {
		return ret;
	}

	sniffer_iow(reg_adr, reg_content);
	return count;
}

static ssize_t sniffer_show_mac1_bad_frames(struct device *dev, struct device_attribute *attr,
                char *buf)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_MAC1_BAD_FRAME_OFFSET;
	u32 reg_content;

	reg_content = sniffer_ior(reg_adr);
	return sysfs_emit(buf, "%u\n", reg_content);
}

static ssize_t sniffer_store_mac1_bad_frames(struct device *dev, struct device_attribute *attr,
                const char *buf, size_t count)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_MAC1_BAD_FRAME_OFFSET;
	u32 reg_content;
	int ret;

	ret = kstrtouint(buf, 0, &reg_content);
	if (ret) {
		return ret;
	}

	sniffer_iow(reg_adr, reg_content);
	return count;
}

static ssize_t sniffer_show_mac2_bad_frames(struct device *dev, struct device_attribute *attr,
                char *buf)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_MAC2_BAD_FRAME_OFFSET;
	u32 reg_content;

	reg_content = sniffer_ior(reg_adr);
	return sysfs_emit(buf, "%u\n", reg_content);
}

static ssize_t sniffer_store_mac2_bad_frames(struct device *dev, struct device_attribute *attr,
                const char *buf, size_t count)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_MAC2_BAD_FRAME_OFFSET;
	u32 reg_content;
	int ret;

	ret = kstrtouint(buf, 0, &reg_content);
	if (ret) {
		return ret;
	}

	sniffer_iow(reg_adr, reg_content);
	return count;
}

static ssize_t sniffer_show_mac1_bad_fcs(struct device *dev, struct device_attribute *attr,
                char *buf)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_MAC1_BAD_FCS_OFFSET;
	u32 reg_content;

	reg_content = sniffer_ior(reg_adr);
	return sysfs_emit(buf, "%u\n", reg_content);
}

static ssize_t sniffer_store_mac1_bad_fcs(struct device *dev, struct device_attribute *attr,
                const char *buf, size_t count)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_MAC1_BAD_FCS_OFFSET;
	u32 reg_content;
	int ret;

	ret = kstrtouint(buf, 0, &reg_content);
	if (ret) {
		return ret;
	}

	sniffer_iow(reg_adr, reg_content);
	return count;
}

static ssize_t sniffer_show_mac2_bad_fcs(struct device *dev, struct device_attribute *attr,
                char *buf)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_MAC2_BAD_FCS_OFFSET;
	u32 reg_content;

	reg_content = sniffer_ior(reg_adr);
	return sysfs_emit(buf, "%u\n", reg_content);
}

static ssize_t sniffer_store_mac2_bad_fcs(struct device *dev, struct device_attribute *attr,
                const char *buf, size_t count)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_MAC2_BAD_FCS_OFFSET;
	u32 reg_content;
	int ret;

	ret = kstrtouint(buf, 0, &reg_content);
	if (ret) {
		return ret;
	}

	sniffer_iow(reg_adr, reg_content);
	return count;
}

static ssize_t sniffer_show_fifo1_bad_frames(struct device *dev, struct device_attribute *attr,
                char *buf)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_FIFO1_BAD_FRAME_OFFSET;
	u32 reg_content;

	reg_content = sniffer_ior(reg_adr);
	return sysfs_emit(buf, "%u\n", reg_content);
}

static ssize_t sniffer_store_fifo1_bad_frames(struct device *dev, struct device_attribute *attr,
                const char *buf, size_t count)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_FIFO1_BAD_FRAME_OFFSET;
	u32 reg_content;
	int ret;

	ret = kstrtouint(buf, 0, &reg_content);
	if (ret) {
		return ret;
	}

	sniffer_iow(reg_adr, reg_content);
	return count;
}

static ssize_t sniffer_show_fifo2_bad_frames(struct device *dev, struct device_attribute *attr,
                char *buf)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_FIFO2_BAD_FRAME_OFFSET;
	u32 reg_content;

	reg_content = sniffer_ior(reg_adr);
	return sysfs_emit(buf, "%u\n", reg_content);
}

static ssize_t sniffer_store_fifo2_bad_frames(struct device *dev, struct device_attribute *attr,
                const char *buf, size_t count)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_FIFO2_BAD_FRAME_OFFSET;
	u32 reg_content;
	int ret;

	ret = kstrtouint(buf, 0, &reg_content);
	if (ret) {
		return ret;
	}

	sniffer_iow(reg_adr, reg_content);
	return count;
}

static ssize_t sniffer_show_fifo1_good_frames(struct device *dev, struct device_attribute *attr,
                char *buf)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_FIFO1_GOOD_FRAME_OFFSET;
	u32 reg_content;

	reg_content = sniffer_ior(reg_adr);
	return sysfs_emit(buf, "%u\n", reg_content);
}

static ssize_t sniffer_store_fifo1_good_frames(struct device *dev, struct device_attribute *attr,
                const char *buf, size_t count)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_FIFO1_GOOD_FRAME_OFFSET;
	u32 reg_content;
	int ret;

	ret = kstrtouint(buf, 0, &reg_content);
	if (ret) {
		return ret;
	}

	sniffer_iow(reg_adr, reg_content);
	return count;
}

static ssize_t sniffer_show_fifo2_good_frames(struct device *dev, struct device_attribute *attr,
                char *buf)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_FIFO2_GOOD_FRAME_OFFSET;
	u32 reg_content;

	reg_content = sniffer_ior(reg_adr);
	return sysfs_emit(buf, "%u\n", reg_content);
}

static ssize_t sniffer_store_fifo2_good_frames(struct device *dev, struct device_attribute *attr,
                const char *buf, size_t count)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_FIFO2_GOOD_FRAME_OFFSET;
	u32 reg_content;
	int ret;

	ret = kstrtouint(buf, 0, &reg_content);
	if (ret) {
		return ret;
	}

	sniffer_iow(reg_adr, reg_content);
	return count;
}

static ssize_t sniffer_show_fifo1_overflow(struct device *dev, struct device_attribute *attr,
                char *buf)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_FIFO1_OVERFLOW_OFFSET;
	u32 reg_content;

	reg_content = sniffer_ior(reg_adr);
	return sysfs_emit(buf, "%u\n", reg_content);
}

static ssize_t sniffer_store_fifo1_overflow(struct device *dev, struct device_attribute *attr,
                const char *buf, size_t count)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_FIFO1_OVERFLOW_OFFSET;
	u32 reg_content;
	int ret;

	ret = kstrtouint(buf, 0, &reg_content);
	if (ret) {
		return ret;
	}

	sniffer_iow(reg_adr, reg_content);
	return count;
}

static ssize_t sniffer_show_fifo2_overflow(struct device *dev, struct device_attribute *attr,
                char *buf)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_FIFO2_OVERFLOW_OFFSET;
	u32 reg_content;

	reg_content = sniffer_ior(reg_adr);
	return sysfs_emit(buf, "%u\n", reg_content);
}

static ssize_t sniffer_store_fifo2_overflow(struct device *dev, struct device_attribute *attr,
                const char *buf, size_t count)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_FIFO2_OVERFLOW_OFFSET;
	u32 reg_content;
	int ret;

	ret = kstrtouint(buf, 0, &reg_content);
	if (ret) {
		return ret;
	}

	sniffer_iow(reg_adr, reg_content);
	return count;
}

static ssize_t sniffer_show_dma_count(struct device *dev, struct device_attribute *attr,
                char *buf)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);

	return sysfs_emit(buf, "%u\n", sniffer_get_dma_count(lp));
}

static ssize_t sniffer_store_dma_count(struct device *dev, struct device_attribute *attr,
                const char *buf, size_t count)
{
	struct sniffer_local *lp = dev_get_drvdata(dev);
	void __iomem *reg_adr = lp->regs + SNIFFER_DMA_PACKET_COUNT_OFFSET;
	u32 reg_content;
	int ret;

	ret = kstrtouint(buf, 0, &reg_content);
	if (ret) {
		return ret;
	}

	sniffer_iow(reg_adr, reg_content);
	return count;
}

static DEVICE_ATTR(speed, S_IRUGO | S_IWUSR, sniffer_show_speed, sniffer_store_speed);
static DEVICE_ATTR(powerdown, S_IRUGO | S_IWUSR, sniffer_show_powerdown, sniffer_store_powerdown);
static DEVICE_ATTR(mac1_start_frames, S_IRUGO | S_IWUSR, sniffer_show_mac1_start_frames, sniffer_store_mac1_start_frames);
static DEVICE_ATTR(mac2_start_frames, S_IRUGO | S_IWUSR, sniffer_show_mac2_start_frames, sniffer_store_mac2_start_frames);
static DEVICE_ATTR(mac1_bad_frames, S_IRUGO | S_IWUSR, sniffer_show_mac1_bad_frames, sniffer_store_mac1_bad_frames);
static DEVICE_ATTR(mac2_bad_frames, S_IRUGO | S_IWUSR, sniffer_show_mac2_bad_frames, sniffer_store_mac2_bad_frames);
static DEVICE_ATTR(mac1_bad_fcs, S_IRUGO | S_IWUSR, sniffer_show_mac1_bad_fcs, sniffer_store_mac1_bad_fcs);
static DEVICE_ATTR(mac2_bad_fcs, S_IRUGO | S_IWUSR, sniffer_show_mac2_bad_fcs, sniffer_store_mac2_bad_fcs);
static DEVICE_ATTR(fifo1_bad_frames, S_IRUGO | S_IWUSR, sniffer_show_fifo1_bad_frames, sniffer_store_fifo1_bad_frames);
static DEVICE_ATTR(fifo2_bad_frames, S_IRUGO | S_IWUSR, sniffer_show_fifo2_bad_frames, sniffer_store_fifo2_bad_frames);
static DEVICE_ATTR(fifo1_good_frames, S_IRUGO | S_IWUSR, sniffer_show_fifo1_good_frames, sniffer_store_fifo1_good_frames);
static DEVICE_ATTR(fifo2_good_frames, S_IRUGO | S_IWUSR, sniffer_show_fifo2_good_frames, sniffer_store_fifo2_good_frames);
static DEVICE_ATTR(fifo1_overflow, S_IRUGO | S_IWUSR, sniffer_show_fifo1_overflow, sniffer_store_fifo1_overflow);
static DEVICE_ATTR(fifo2_overflow, S_IRUGO | S_IWUSR, sniffer_show_fifo2_overflow, sniffer_store_fifo2_overflow);
static DEVICE_ATTR(dma_count, S_IRUGO | S_IWUSR, sniffer_show_dma_count, sniffer_store_dma_count);


int sniffer_setup_sysfs(struct sniffer_local *lp)
{
	int ret;

	ret = device_create_file(lp->dev, &dev_attr_powerdown);
	if (ret) {
		dev_err(lp->dev, "Unable to register powerdown file\n");
		return ret;
	}

	ret = device_create_file(lp->dev, &dev_attr_speed);
	if (ret) {
		dev_err(lp->dev, "Unable to register speed file\n");
		return ret;
	}

        ret = device_create_file(lp->dev, &dev_attr_mac1_start_frames);
	if (ret) {
		dev_err(lp->dev, "Unable to register mac1_start_frames file\n");
		return ret;
	}

	ret = device_create_file(lp->dev, &dev_attr_mac2_start_frames);
	if (ret) {
		dev_err(lp->dev, "Unable to register mac2_start_frames file\n");
		return ret;
	}

	ret = device_create_file(lp->dev, &dev_attr_mac1_bad_frames);
	if (ret) {
		dev_err(lp->dev, "Unable to register mac1_bad_frames file\n");
		return ret;
	}

	ret = device_create_file(lp->dev, &dev_attr_mac2_bad_frames);
	if (ret) {
		dev_err(lp->dev, "Unable to register mac2_bad_frames file\n");
		return ret;
	}

	ret = device_create_file(lp->dev, &dev_attr_mac1_bad_fcs);
	if (ret) {
		dev_err(lp->dev, "Unable to register mac1_bad_fcs file\n");
		return ret;
	}

	ret = device_create_file(lp->dev, &dev_attr_mac2_bad_fcs);
	if (ret) {
		dev_err(lp->dev, "Unable to register mac2_bad_fcs file\n");
		return ret;
	}

	ret = device_create_file(lp->dev, &dev_attr_fifo1_bad_frames);
	if (ret) {
		dev_err(lp->dev, "Unable to register fifo1_bad_frames file\n");
		return ret;
	}

	ret = device_create_file(lp->dev, &dev_attr_fifo2_bad_frames);
	if (ret) {
		dev_err(lp->dev, "Unable to register fifo2_bad_frames file\n");
		return ret;
	}

	ret = device_create_file(lp->dev, &dev_attr_fifo1_good_frames);
	if (ret) {
		dev_err(lp->dev, "Unable to register fifo1_good_frames file\n");
		return ret;
	}

	ret = device_create_file(lp->dev, &dev_attr_fifo2_good_frames);
	if (ret) {
		dev_err(lp->dev, "Unable to register fifo2_good_frames file\n");
		return ret;
	}

	ret = device_create_file(lp->dev, &dev_attr_fifo1_overflow);
	if (ret) {
		dev_err(lp->dev, "Unable to register fifo1_overflow file\n");
		return ret;
	}

        ret = device_create_file(lp->dev, &dev_attr_fifo2_overflow);
	if (ret) {
		dev_err(lp->dev, "Unable to register fifo2_overflow file\n");
		return ret;
	}

        ret = device_create_file(lp->dev, &dev_attr_dma_count);
	if (ret) {
		dev_err(lp->dev, "Unable to register dma_count file\n");
		return ret;
	}

	return ret;
}
