// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * Driver for the Real-Time Sniffer aRTS
 *
 * 2023 (c) Chris H. Meyer
 */

#include <linux/netdevice.h>
#include <linux/spinlock.h>
#include <linux/interrupt.h>
#include <linux/if_vlan.h>
#include <linux/phylink.h>
#include <linux/types.h>
#include <linux/list.h>
#include <linux/completion.h>
#include <linux/miscdevice.h>
#include <linux/rwsem.h>
#include <asm/atomic.h>


#define SNIFFER_MDIO_BUS_COUNT 2

#define DMA_DESC_SIZE sizeof(struct sniffer_dma_descriptor)
#define DMA_DESC_RING_SIZE 256
#define DMA_DESC_RING_MASK (DMA_DESC_RING_SIZE-1)
#define DMA_BUF_SIZE_LD 11
#define DMA_BUF_SIZE (1 << DMA_BUF_SIZE_LD)
#define DMA_BUF_RING_SIZE ((256 * 1024 * 1024) / DMA_BUF_SIZE)
#define DMA_BUF_RING_MASK ((256 * 1024 * 1024) / DMA_BUF_SIZE)

struct sniffer_dma_descriptor {
	u64 buf_addr;
	u32 buf_len;
	u32 flags;
} __attribute__ ((packed));

struct sniffer_pcap_buff {
	struct sniffer_pcap_buff *next;
	struct completion packet_received;
	u8 *payload;
	unsigned int i;
};

struct sniffer_local {
	struct net_device *ndev;
	struct device *dev;

	void __iomem *regs;

	struct phylink *phylink[SNIFFER_MDIO_BUS_COUNT];
	struct phy_device *phydev[SNIFFER_MDIO_BUS_COUNT];
	struct phylink_config phylink_config;
	void *mii_bus[SNIFFER_MDIO_BUS_COUNT];

	struct mutex running;
	bool powerdown:1;
	unsigned int speed;

	struct sniffer_dma_descriptor *dma_desc;
	dma_addr_t dma_handle;
	u8 *buf;
	unsigned int buf_size;
	void *dummy_buf;
	dma_addr_t dummy_dma_handle;
	unsigned int dma_count;

	unsigned int desc_tail;
	unsigned int data_tail, data_head;
	unsigned int data_desc_head;
	int i;

	wait_queue_head_t queue;
	//workqueue_head_t queue;

	int rd_error;

	struct miscdevice misc_dev;
};



int sniffer_setup_phylink(struct sniffer_local *lp);
int sniffer_setup_miscdevice(struct sniffer_local *lp);
int sniffer_setup_sysfs(struct sniffer_local *lp);
int set_speed(struct sniffer_local *lp, unsigned int speed);
int fill_dummy_dma_descriptor(struct sniffer_local *lp);
int prepare_dma_descriptor_ring(struct sniffer_local *lp);
int sniffer_mdio_setup(struct sniffer_local *lp);
void sniffer_mdio_teardown(struct sniffer_local *lp);

#define SNIFFER_DMA_OFFSET 0x0
#define SNIFFER_MAC_OFFSET 0x100
#define SNIFFER_MDIO1_OFFSET 0x200
#define SNIFFER_MDIO2_OFFSET 0x204

#define SNIFFER_DMA_ADR_OFFSET (SNIFFER_DMA_OFFSET + 0x0)
#define SNIFFER_DMA_LEN_OFFSET (SNIFFER_DMA_OFFSET + 0x4)
#define SNIFFER_DMA_CTRL_OFFSET (SNIFFER_DMA_OFFSET + 0x8)
#define SNIFFER_DMA_STATUS_OFFSET (SNIFFER_DMA_OFFSET + 0xc)
#define SNIFFER_DMA_IRQ_TIME_OFFSET (SNIFFER_DMA_OFFSET + 0x10)
#define SNIFFER_DMA_PACKET_COUNT_OFFSET (SNIFFER_DMA_OFFSET + 0x14)

#define SNIFFER_DMA_STATUS_BUSY_OFFSET 0
#define SNIFFER_DMA_STATUS_IRQ_OFFSET 1
#define SNIFFER_DMA_STATUS_BUSY_MASK (0x1 << SNIFFER_DMA_STATUS_BUSY_OFFSET)
#define SNIFFER_DMA_STATUS_IRQ_MASK (0x1 << SNIFFER_DMA_STATUS_IRQ_OFFSET)

#define SNIFFER_DMA_CTRL_ENABLE_OFFSET 0
#define SNIFFER_DMA_CTRL_RESET_OFFSET 1
#define SNIFFER_DMA_CTRL_IRQ_OFFSET 2

#define SNIFFER_DMA_CTRL_ENABLE_MASK (0x1 << SNIFFER_DMA_CTRL_ENABLE_OFFSET)
#define SNIFFER_DMA_CTRL_RESET_MASK (0x1 << SNIFFER_DMA_CTRL_RESET_OFFSET)
#define SNIFFER_DMA_CTRL_IRQ_MASK (0x1 << SNIFFER_DMA_CTRL_IRQ_OFFSET)


#define SNIFFER_MAC_CTRL_OFFSET (SNIFFER_MAC_OFFSET + 0x00)
#define SNIFFER_MAC_STATUS_OFFSET (SNIFFER_MAC_OFFSET + 0x04)
#define SNIFFER_MAC_MAC1_START_FRAME_OFFSET (SNIFFER_MAC_OFFSET + 0x40)
#define SNIFFER_MAC_MAC1_BAD_FRAME_OFFSET (SNIFFER_MAC_OFFSET + 0x44)
#define SNIFFER_MAC_MAC1_BAD_FCS_OFFSET (SNIFFER_MAC_OFFSET + 0x48)
#define SNIFFER_MAC_FIFO1_BAD_FRAME_OFFSET (SNIFFER_MAC_OFFSET + 0x4c)
#define SNIFFER_MAC_FIFO1_GOOD_FRAME_OFFSET (SNIFFER_MAC_OFFSET + 0x50)
#define SNIFFER_MAC_FIFO1_OVERFLOW_OFFSET (SNIFFER_MAC_OFFSET + 0x54)
#define SNIFFER_MAC_MAC2_START_FRAME_OFFSET (SNIFFER_MAC_OFFSET + 0x60)
#define SNIFFER_MAC_MAC2_BAD_FRAME_OFFSET (SNIFFER_MAC_OFFSET + 0x64)
#define SNIFFER_MAC_MAC2_BAD_FCS_OFFSET (SNIFFER_MAC_OFFSET + 0x68)
#define SNIFFER_MAC_FIFO2_BAD_FRAME_OFFSET (SNIFFER_MAC_OFFSET + 0x6c)
#define SNIFFER_MAC_FIFO2_GOOD_FRAME_OFFSET (SNIFFER_MAC_OFFSET + 0x70)
#define SNIFFER_MAC_FIFO2_OVERFLOW_OFFSET (SNIFFER_MAC_OFFSET + 0x74)

#define SNIFFER_MAC_CTRL_ENABLE_OFFSET 0x0
#define SNIFFER_MAC_CTRL_MII_OFFSET 0x1
#define SNIFFER_MAC_CTRL_RESET_OFFSET 0x2
#define SNIFFER_MAC_CTRL_ENABLE_MASK (0x1 << SNIFFER_MAC_CTRL_ENABLE_OFFSET)
#define SNIFFER_MAC_CTRL_MII_MASK (0x1 << SNIFFER_MAC_CTRL_MII_OFFSET)
#define SNIFFER_MAC_CTRL_RESET_MASK (0x1 << SNIFFER_MAC_CTRL_RESET_OFFSET)

#define SNIFFER_MAC_STATUS_BUSY_OFFSET 0x0
#define SNIFFER_MAC_STATUS_BUFFERS_EMPTY_OFFSET 0x1
#define SNIFFER_MAC_STATUS_BUSY_MASK (0x1 << SNIFFER_MAC_STATUS_BUSY_OFFSET)
#define SNIFFER_MAC_STATUS_BUFFERS_EMPTY_MASK (0x1 << SNIFFER_MAC_STATUS_BUFFERS_EMPTY_OFFSET)


#define SNIFFER_MDIO_OP_WRITE 0x1
#define SNIFFER_MDIO_OP_READ 0x2

#define SNIFFER_MDIO_READY_MASK (0x00000001 << SNIFFER_MDIO_READY_SHIFT)
#define SNIFFER_MDIO_OP_MASK (0x00000003 << SNIFFER_MDIO_OP_SHIFT)
#define SNIFFER_MDIO_PHYADR_MASK (0x0000001F << SNIFFER_MDIO_PHYADR_SHIFT)
#define SNIFFER_MDIO_REGADR_MASK (0x0000001F << SNIFFER_MDIO_REGADR_SHIFT)
#define SNIFFER_MDIO_DATA_MASK (0x0000FFFF << SNIFFER_MDIO_DATA_SHIFT)

#define SNIFFER_MDIO_READY_SHIFT 28
#define SNIFFER_MDIO_OP_SHIFT 26
#define SNIFFER_MDIO_PHYADR_SHIFT 21
#define SNIFFER_MDIO_REGADR_SHIFT 16
#define SNIFFER_MDIO_DATA_SHIFT 0


#define SNIFFER_DMA_DESC_FLAG_EMPTY 0x1
#define SNIFFER_DMA_DESC_FLAG_WRAP 0x2


/**
 * sniffer_iow - Memory mapped ART Sniffer register write
 * @lp:         Pointer to sniffer local structure
 * @offset:     Address offset from the base address of the Sniffer registers
 * @value:      Value to be written into the ART Sniffer register
 *
 * This function writes the desired value into the corresponding ART Sniffer
 * register.
 */
static inline void sniffer_iow(void __iomem *regs, u32 value)
{
	iowrite32(value, regs);
}


static inline u32 sniffer_ior(void __iomem *regs)
{
	return ioread32(regs);
}

static inline u32 sniffer_get_dma_count(struct sniffer_local *lp)
{
	void __iomem *reg_adr = lp->regs + SNIFFER_DMA_PACKET_COUNT_OFFSET;
	u32 reg_content;

	reg_content = sniffer_ior(reg_adr);
	return reg_content;
}

