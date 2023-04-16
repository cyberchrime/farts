// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * Driver for the Real-Time Sniffer aRTS
 *
 * 2023 (c) Chris H. Meyer
 */

#include <linux/fs.h>
#include <linux/circ_buf.h>

#include "sniffer.h"
/*
Simple aprroach: each packet is transmitted in a separate buffer.
Reserve a packet of size 2KB. After a packet was transmitted successfully, emit an IRQ.

Put pointer to a singly linked list.
The PCAP header contains the size of the payload, i.e. put only the real payload to the
char file.
Afterwards, free the list entry as well as the PCAP record.

After the



Further possibilities:
Use large buffers with timeouts. The timeout resets each time a packet arrives.
Once the timeout is

Problem with this approach: How to deal with oversized packets?
Solution: Have a small backup buffer, capable of receiving all overflowing bytes.
The size should be at least the size of a packet of max. size.



*/

static void disable_dma(struct sniffer_local *lp)
{
	void __iomem *reg_adr;
	u32 reg_content;

	reg_adr = lp->regs + SNIFFER_DMA_CTRL_OFFSET;
	reg_content = sniffer_ior(reg_adr);
	sniffer_iow(reg_adr, reg_content & ~SNIFFER_DMA_CTRL_ENABLE_MASK);
}

static void enable_dma(struct sniffer_local *lp)
{
	void __iomem *reg_adr = lp->regs + SNIFFER_DMA_CTRL_OFFSET;
	u32 reg_content;

	reg_content = sniffer_ior(reg_adr);
	sniffer_iow(reg_adr, reg_content | SNIFFER_DMA_CTRL_ENABLE_MASK);
}

static int await_reset_dma(struct sniffer_local *lp)
{
	void __iomem *reg_adr = lp->regs + SNIFFER_DMA_CTRL_OFFSET;
	u32 reg_content;

	return readx_poll_timeout(sniffer_ior, reg_adr, reg_content,
			!(reg_content & SNIFFER_DMA_CTRL_RESET_MASK),
			1, 20000);
}

static void reset_dma(struct sniffer_local *lp)
{
	void __iomem *reg_adr = lp->regs + SNIFFER_DMA_CTRL_OFFSET;
	u32 reg_content;

	reg_content = sniffer_ior(reg_adr);
	sniffer_iow(reg_adr, reg_content | SNIFFER_DMA_CTRL_RESET_MASK);
}

static void disable_macs(struct sniffer_local *lp)
{
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_CTRL_OFFSET;
	u32 reg_content = sniffer_ior(reg_adr);

	sniffer_iow(reg_adr, reg_content & ~SNIFFER_MAC_CTRL_ENABLE_MASK);
}

static int await_mac_not_busy(struct sniffer_local *lp)
{
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_STATUS_OFFSET;
	u32 reg_content;

	return readx_poll_timeout(sniffer_ior, reg_adr, reg_content,
			!(reg_content & SNIFFER_MAC_STATUS_BUSY_MASK),
			1, 20000);
}

static void reset_macs(struct sniffer_local *lp)
{
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_CTRL_OFFSET;
	u32 reg_content;

	reg_content = sniffer_ior(reg_adr);
	sniffer_iow(reg_adr, reg_content | SNIFFER_MAC_CTRL_RESET_MASK);
}

static void enable_macs(struct sniffer_local *lp)
{
	void __iomem *reg_adr = lp->regs + SNIFFER_MAC_CTRL_OFFSET;
	u32 reg_content;

	reg_content = sniffer_ior(reg_adr);
	sniffer_iow(reg_adr, reg_content | SNIFFER_MAC_CTRL_ENABLE_MASK);
}

static int await_dma_not_busy(struct sniffer_local *lp)
{
	void __iomem *reg_adr = lp->regs + SNIFFER_DMA_STATUS_OFFSET;
	u32 reg_content;
	u32 mask = SNIFFER_DMA_STATUS_BUSY_MASK | SNIFFER_DMA_STATUS_IRQ_MASK;

	return readx_poll_timeout(sniffer_ior, reg_adr, reg_content,
			!(reg_content & mask), 1, 20000);
}

static int sniffer_open(struct inode *inode, struct file *file)
{
	void __iomem *reg_adr;
	struct sniffer_local *lp;
	u32 reg_content;
	int ret;
	struct phy_device *phydev;
	int i;

	lp = container_of(file->private_data, struct sniffer_local, misc_dev);

	if (!mutex_trylock(&lp->running)) {
		dev_err(lp->dev, "Opening more than one device is illegal");
		return -EBUSY;
	}

	dev_dbg(lp->dev, "Starting...\n");

	dev_dbg(lp->dev, "Preparing MAC status address...\n");
	reg_adr = lp->regs + SNIFFER_MAC_STATUS_OFFSET;
	dev_dbg(lp->dev, "Reading MAC status regs...\n");
	reg_content = sniffer_ior(reg_adr);

	dev_dbg(lp->dev, "Read 0x%08x\n from address 0x%08x\n", reg_content, (u32) reg_adr);
	dev_dbg(lp->dev, "Checking whether buffers are ready...\n");
	if (!(reg_content & SNIFFER_MAC_STATUS_BUFFERS_EMPTY_MASK)) {
		dev_warn(lp->dev, "Device not yet ready (buffers not empty)\n");
		return -EAGAIN;
	}

	dev_dbg(lp->dev, "Set running...\n");

	dev_dbg(lp->dev, "Disabling DMA...\n");
	disable_dma(lp);

	dev_dbg(lp->dev, "Waiting for DMA...\n");
	ret = await_dma_not_busy(lp);
	if (ret) {
		dev_err(lp->dev, "Waiting for DMA takes too long...\n");
		mutex_unlock(&lp->running);
		return ret;
	}

	dev_dbg(lp->dev, "Reset DMA...");
	reset_dma(lp);

	dev_dbg(lp->dev, "Await resetting DMA...");
	ret = await_reset_dma(lp);
	if (ret) {
		dev_err(lp->dev, "Resetting DMA takes too long...\n");
		mutex_unlock(&lp->running);
		return ret;
	}

	dev_dbg(lp->dev, "Preparing DMA...\n");
	ret = prepare_dma_descriptor_ring(lp);
	if (ret) {
		mutex_unlock(&lp->running);
		return ret;
	}

	dev_dbg(lp->dev, "Enabling DMA...\n");
	enable_dma(lp);
	dev_dbg(lp->dev, "Enabling MACs...\n");

	reset_macs(lp);
	enable_macs(lp);

	if (lp->powerdown) {
		dev_dbg(lp->dev, "Powering up PHYs...\n");
		for (i = 0; i < SNIFFER_MDIO_BUS_COUNT; i++) {
			phydev = lp->phydev[i];
			phy_resume(phydev);
		}
	}

	dev_dbg(lp->dev, "Successfully started sniffing!\n");

	return 0;
}

static int sniffer_close(struct inode *inode, struct file *file)
{
	struct sniffer_local *lp;
	int i;
	int ret;
	struct phy_device *phydev;

	lp = container_of(file->private_data, struct sniffer_local, misc_dev);

	dev_info(lp->dev, "data_head=%u, data_tail=%u\n", lp->data_head, lp->data_tail);

	disable_macs(lp);

	disable_dma(lp);

	await_dma_not_busy(lp);
	ret = fill_dummy_dma_descriptor(lp);
	if (ret) {
		dev_err(lp->dev, "Unable to fill dummy dma descriptor\n");
		return ret;
	}

	enable_dma(lp);

	ret = await_mac_not_busy(lp);
	if (ret) {
		dev_warn(lp->dev, "MAC is still busy...\n");
		return ret;
	}

	for (i = 0; i < SNIFFER_MDIO_BUS_COUNT; i++) {
		phydev = lp->phydev[i];
		if (lp->powerdown) {
			phy_suspend(phydev);
		}
	}

	mutex_unlock(&lp->running);

	return 0;
}

static unsigned int get_data_count(struct sniffer_local *lp)
{
	unsigned int head = smp_load_acquire(&lp->data_head);
	unsigned int tail = lp->data_tail;

	return CIRC_CNT(head, tail, lp->buf_size);
}

static bool is_data_empty(struct sniffer_local *lp)
{
	return get_data_count(lp) == 0;
}

static bool is_data_available(struct sniffer_local *lp)
{
	return get_data_count(lp) >= 1;
}

static ssize_t sniffer_read (struct file *filp, char __user *ubuf, size_t count, loff_t *off)
{
	int ret = 0;
	unsigned int i = 0;

	struct sniffer_local *lp;
	unsigned int error_count, remaining_bytes;
	u32 length;
	u8 *payload;
	unsigned int data_ptr;

	lp = container_of(filp->private_data, struct sniffer_local, misc_dev);

	if (lp->rd_error) {
		ret = lp->rd_error;
		lp->rd_error = 0;
		return ret;
	}

	if (!lp->i) { // the previous packet was read completely...
		ret = wait_event_interruptible(lp->queue, is_data_available(lp));

		if (ret) // usually an interrupt occurred
			return ret;
	}

	data_ptr = lp->data_tail << DMA_BUF_SIZE_LD;
	payload = lp->buf + data_ptr;
	length = le32_to_cpup(((__le32 *) payload) + 3);
	length += 16; // add header length
	remaining_bytes = length - lp->i;

	// does the data completely fit into the buffer?
	if (count < remaining_bytes) {
		error_count = copy_to_user(ubuf, payload + lp->i, count);
		lp->i = lp->i + count;

		if (error_count) {
			lp->rd_error = EIO;
			return count - error_count;
		}
	} else {
		error_count = copy_to_user(ubuf, payload + lp->i, remaining_bytes);
		count = remaining_bytes - error_count;
		lp->i = 0;

		if (error_count) {
			lp->rd_error = EIO;
			return count;
		}

		// release buffer
		smp_store_release(&lp->data_tail,
				  (lp->data_tail + 1) & (lp->buf_size - 1));
		// TODO: run a workqueue in case the descriptor buffer is full
	}


	return count;
}

static ssize_t sniffer_write (struct file *filp, const char __user *ubuf, size_t count, loff_t *off)
{
	return -ENOSYS; // Function not implemented
}

static loff_t sniffer_llseek (struct file *file, loff_t offset, int whence)
{
	return -ENOSYS; // Function not implemented
}

const struct file_operations sniffer_fops = {
	.owner = THIS_MODULE,
	.open = sniffer_open,
	.release = sniffer_close,
	.read = sniffer_read,
	.write = sniffer_write,
	.llseek = sniffer_llseek,
};


int sniffer_setup_miscdevice(struct sniffer_local *lp)
{
	lp->misc_dev.minor = MISC_DYNAMIC_MINOR;
	lp->misc_dev.name = "sniffer";
	lp->misc_dev.fops = &sniffer_fops;
	lp->misc_dev.parent = lp->dev;
	return misc_register(&lp->misc_dev);
}
