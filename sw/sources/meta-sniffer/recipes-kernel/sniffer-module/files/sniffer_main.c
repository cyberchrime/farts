// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * Driver for the Real-Time Sniffer aRTS
 *
 * 2023 (c) Chris H. Meyer
 */

#include <linux/platform_device.h>
#include <linux/slab.h>
#include <linux/gfp.h>
#include <linux/printk.h>
#include <linux/memory.h>
#include <linux/phylink.h>
#include <linux/dma-mapping.h>
#include <linux/of_reserved_mem.h>
#include <linux/of_address.h>
#include <linux/circ_buf.h>

#include "sniffer.h"

static int setup_dummy_buf(struct sniffer_local *lp)
{
	lp->dummy_buf = kmalloc(DMA_BUF_SIZE, GFP_KERNEL);
	lp->dummy_dma_handle = dma_map_single(lp->dev, lp->dummy_buf,
			DMA_BUF_SIZE, DMA_FROM_DEVICE);

	if (dma_mapping_error(lp->dev, lp->dma_handle)) {
		dev_err(lp->dev, "Unable to map DMA");
		return -ENOMEM;
	}

	return 0;
}

int fill_dummy_dma_descriptor(struct sniffer_local *lp) {
	const unsigned int dma_desc_ring_size = DMA_DESC_RING_SIZE;
	struct sniffer_dma_descriptor *dma_desc;
	dma_addr_t dma_handle;
	unsigned int i;
	unsigned int ret;

	ret = setup_dummy_buf(lp);
	if (ret) {
		return ret;
	}

	for (i = 0; i < dma_desc_ring_size; i++) {
		dma_desc = lp->dma_desc + i;
		dma_desc->buf_addr = lp->dummy_dma_handle;
		dma_desc->buf_len = DMA_BUF_SIZE;
		dma_desc->flags = SNIFFER_DMA_DESC_FLAG_EMPTY;
	}


	return 0;
}

void init_descriptor_pointers(struct sniffer_local *lp) {
	int i;

	lp->desc_tail = 0;
	lp->data_tail = 0;
	lp->data_head = 0;
	lp->data_desc_head = 0;
	lp->dma_count = 0;

	lp->i = 0;
}

static int sniffer_dma_setup(struct sniffer_local *lp)
{
	const u32 size = DMA_BUF_SIZE;

	int ret;
	int i;
	struct device_node *np;
	struct resource r;

	init_waitqueue_head(&lp->queue);

	lp->dma_desc = lp->regs + 0x1000;

	ret = of_reserved_mem_device_init(lp->dev);
	if (ret) {
		dev_err(lp->dev, "Could not get reserved memory\n");
		return ret;
	}
	np = of_parse_phandle(lp->dev->of_node, "memory-region", 0);
	if (!np) {
		dev_err(lp->dev, "No %s specified\n", "memory-region");
		return -ENODEV;
	}

	ret = of_address_to_resource(np, 0, &r);
	if (ret) {
		dev_err(lp->dev, "No memory address assigned to RAM region\n");
		return ret;
	}

	ret = dma_set_mask_and_coherent(lp->dev, DMA_BIT_MASK(32));
	if (ret) {
		dev_err(lp->dev, "Could not set dma mask\n");
		return ret;
	}

	lp->dma_handle = r.start;
	lp->buf = dma_alloc_coherent(lp->dev, resource_size(&r), &lp->dma_handle, GFP_KERNEL);
	lp->buf_size = resource_size(&r) >> DMA_BUF_SIZE_LD;

	fill_dummy_dma_descriptor(lp);

	sniffer_iow(lp->regs + SNIFFER_DMA_CTRL_OFFSET,
		SNIFFER_DMA_CTRL_IRQ_MASK | SNIFFER_DMA_CTRL_ENABLE_MASK);

	return 0;
}


int prepare_dma_descriptor_ring(struct sniffer_local *lp)
{
	const unsigned int dma_desc_ring_size = DMA_DESC_RING_SIZE;
	u32 size = DMA_BUF_SIZE;
	dma_addr_t dma_handle;
	unsigned int i;
	struct sniffer_dma_descriptor *dma_desc;


	init_descriptor_pointers(lp);

	dma_handle = lp->dma_handle + (lp->data_head << DMA_BUF_SIZE_LD);
	for (i = 0; i < dma_desc_ring_size; i++) {
		dma_desc = lp->dma_desc + i;
		dma_desc->buf_addr = dma_handle;
		dma_desc->buf_len = size;
		WRITE_ONCE(dma_desc->flags, SNIFFER_DMA_DESC_FLAG_EMPTY);

		lp->data_desc_head++;
		dma_handle = lp->dma_handle + (lp->data_desc_head << DMA_BUF_SIZE_LD);
	}

	lp->desc_tail = 0;

	sniffer_iow(lp->regs + SNIFFER_DMA_CTRL_OFFSET,
		SNIFFER_DMA_CTRL_IRQ_MASK | SNIFFER_DMA_CTRL_ENABLE_MASK);

	return 0;

}

static void running_irq(struct sniffer_local *lp) {
	struct sniffer_dma_descriptor *dma_desc;
	dma_addr_t dma_handle;
	int full;
	unsigned int dma_count;
	unsigned int delta, free_space, i;
	unsigned int tail, head;

	head = lp->data_head;

	// check how many new entries arrived
	dma_count = sniffer_get_dma_count(lp);
	delta = dma_count - lp->dma_count;
	lp->dma_count = dma_count;

	// allow reading new entries
	head = (head + delta) & (lp->buf_size - 1);
	smp_store_release(&lp->data_head, head);
	wake_up_interruptible_sync(&lp->queue);

	tail = READ_ONCE(lp->data_tail);

	// fill as many descriptors as possible
	free_space = min(CIRC_SPACE(lp->data_desc_head, tail, lp->buf_size), delta);

	for (i = 0; i < free_space; i++) {
		dma_desc = lp->dma_desc + lp->desc_tail;

		dma_handle = lp->dma_handle + ((lp->data_desc_head) << DMA_BUF_SIZE_LD);

		dma_desc->buf_addr = dma_handle;
		dma_desc->buf_len = DMA_BUF_SIZE;
		WRITE_ONCE(dma_desc->flags, SNIFFER_DMA_DESC_FLAG_EMPTY);

		lp->desc_tail = (lp->desc_tail + 1) & DMA_DESC_RING_MASK;

		lp->data_desc_head = (lp->data_desc_head + 1) & (lp->buf_size - 1);
	}

}

static void idle_irq(struct sniffer_local *lp) {
	struct sniffer_dma_descriptor *dma_desc;

	dma_desc = lp->dma_desc + lp->desc_tail;

	while (!(dma_desc->flags & SNIFFER_DMA_DESC_FLAG_EMPTY)) {
		dma_desc->buf_len = DMA_BUF_SIZE;
		dma_desc->flags = SNIFFER_DMA_DESC_FLAG_EMPTY;

		lp->desc_tail = (lp->desc_tail + 1) & DMA_DESC_RING_MASK;
		dma_desc = lp->dma_desc + lp->desc_tail;
	}
}

static irqreturn_t sniffer_irq(int irq, void *dev_id)
{
	struct sniffer_local *lp = dev_id;

	u32 reg;
	bool triggered;

	reg = sniffer_ior(lp->regs + SNIFFER_DMA_STATUS_OFFSET);
	triggered = reg & SNIFFER_DMA_STATUS_IRQ_MASK;

	if (!(triggered & 0x1)) // something else triggered the IRQ
		return IRQ_NONE;

	// reset IRQ
	sniffer_iow(lp->regs + SNIFFER_DMA_STATUS_OFFSET, reg);

	if (mutex_is_locked(&lp->running)) {
		running_irq(lp);
	} else {
		idle_irq(lp);
	}

	return IRQ_HANDLED;
}

static int sniffer_probe(struct platform_device *pdev)
{
	int ret, irq;
	struct sniffer_local *lp;

	lp = kzalloc(sizeof(struct sniffer_local), GFP_KERNEL);
	if (!lp)
		return -ENOMEM;

	mutex_init(&lp->running);

	lp->regs = devm_platform_get_and_ioremap_resource(pdev, 0, NULL);
	if (IS_ERR(lp->regs))
		return PTR_ERR(lp->regs);

	dev_dbg(&pdev->dev, "lp->regs = 0x%x\n", (unsigned int) virt_to_phys(lp->regs));

	platform_set_drvdata(pdev, lp);

	lp->dev = &pdev->dev;

	ret = sniffer_mdio_setup(lp);
	if (ret) {
		dev_err(&pdev->dev, "Error registering MDIO buses: %d\n", ret);

		return ret;
	}

	ret = sniffer_setup_phylink(lp);
	if (ret) {
		dev_err(&pdev->dev, "Unable to setup phylinks\n");
		return ret;
	}

	ret = sniffer_dma_setup(lp);
	if (ret) {
		dev_err(&pdev->dev, "Unable to setup DMA\n");
		return ret;
	}

	irq = platform_get_irq(pdev, 0);
	if (irq < 0) {
		dev_err(&pdev->dev, "Couldn't get IRQ\n");
	return irq;
	}

	ret = devm_request_irq(&pdev->dev, irq, sniffer_irq,
			       IRQF_SHARED, pdev->name, lp);
	if (ret) {
		dev_err(&pdev->dev,
			"Unable to request IRQ %d (error %d)\n", irq, ret);
		return ret;
	}

	ret = sniffer_setup_miscdevice(lp);
	if (ret) {
		dev_err(&pdev->dev, "Unable to setup character device\n");
		return ret;
	}

	ret = sniffer_setup_sysfs(lp);
	if (ret) {
		dev_err(&pdev->dev, "Unable to register sysfs files\n");
	}

	return ret;
}

static int sniffer_remove(struct platform_device *pdev)
{
	struct sniffer_local *lp = platform_get_drvdata(pdev);
	int i;


	// TODO: free descriptors
	// TODO: free pcap buffer queue
	// TODO: shutdown DMA
	// TODO: shutdown MACs

	misc_deregister(&lp->misc_dev);

	sniffer_mdio_teardown(lp);

	dma_free_coherent(lp->dev, lp->buf_size << DMA_BUF_SIZE_LD, lp->buf, lp->dma_handle);

	for (i = 0; i < SNIFFER_MDIO_BUS_COUNT; i++) {
		phylink_stop(lp->phylink[i]);
		phylink_disconnect_phy(lp->phylink[i]);
	}

	return 0;
}

static void sniffer_shutdown(struct platform_device *pdev)
{
	return;
}

static const struct of_device_id sniffer_of_match[] = {
	{ .compatible = "art,sniffer", },
	{},
};

static struct platform_driver sniffer_driver = {
	.probe = sniffer_probe,
	.remove = sniffer_remove,
	.shutdown = sniffer_shutdown,
	.driver = {
		 .name = "sniffer",
		 .of_match_table = sniffer_of_match,
	},
};

MODULE_DEVICE_TABLE(of, sniffer_of_match);

module_platform_driver(sniffer_driver);

MODULE_DESCRIPTION("A RealTime (ART) Sniffer");
MODULE_AUTHOR("Christian H. Meyer");
MODULE_LICENSE("GPL v2");
