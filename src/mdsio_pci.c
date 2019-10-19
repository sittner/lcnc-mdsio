//
//    Copyright (C) 2011 Sascha Ittner <sascha.ittner@modusoft.de>
//
//    This program is free software; you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation; either version 2 of the License, or
//    (at your option) any later version.
//
//    This program is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with this program; if not, write to the Free Software
//    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
//

#include "rtapi.h"
#include "rtapi_app.h"
#include "rtapi_string.h"
#include "rtapi_pci.h"
#include "rtapi_slab.h"

#include <linux/pci.h>

#include "hal.h"

#include "mdsio_pci.h"
#include "mdsio.h"

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Sascha Ittner <sascha.ittner@modusoft.de>");
MODULE_DESCRIPTION("Driver for mdsIO on FPGA based pci boards");
MODULE_SUPPORTED_DEVICE("mdsIO PCI board");

static struct rtapi_pci_device_id mdsio_pci_tbl[] = {
  {
    .vendor = MDSIO_PCILITE_VID,
    .device = MDSIO_PCILITE_PID,
    .subvendor = MDSIO_PCILITE_SUB_VID,
    .subdevice = MDSIO_PCILITE_SUB_PID,
  },
  {0,}
};

MODULE_DEVICE_TABLE(pci, mdsio_pci_tbl);

uint32_t mdsio_pci_read_conf(mdsio_port_t *port, int word) {
  mdsio_pci_board_t *board = (mdsio_pci_board_t *)port->device_data;
  return ((uint32_t *)(board->base))[word];
}

void mdsio_pci_read_data(mdsio_port_t *port) {
  mdsio_pci_board_t *board = (mdsio_pci_board_t *)port->device_data;

  memcpy(port->input_data, (board->base + port->data_offset), port->data_len);
}

void mdsio_pci_write_data(mdsio_port_t *port) {
  mdsio_pci_board_t *board = (mdsio_pci_board_t *)port->device_data;

  memcpy((board->base + port->data_offset), port->output_data, port->data_len);
}

static mdsio_dev_t mdsio_device = {
  .name = MDSIO_PCI_NAME,
  .osc_freq = MDSIO_PCI_OSC_FREQ,
  .proc_read_conf = mdsio_pci_read_conf,
  .proc_read_input = mdsio_pci_read_data,
  .proc_write_output = mdsio_pci_write_data
};

static int mdsio_pci_probe(struct rtapi_pci_dev *dev, const struct rtapi_pci_device_id *ent) {
  mdsio_pci_board_t *board;
  mdsio_port_t *port;
  int err;

  // Enabling PCI device
  if (rtapi_pci_enable_device(dev) < 0) {
    rtapi_print_msg(RTAPI_MSG_ERR, "%s: Enabling PCI device failed\n", MDSIO_PCI_NAME);
    err = -ENOMEM;
    goto fail0;
  }

  // Allocating board structures to hold addresses, ...
  board = rtapi_kzalloc(sizeof(mdsio_pci_board_t), GFP_KERNEL);
  if (board == NULL) {
    rtapi_print_msg(RTAPI_MSG_ERR, "%s: Unable to allocate memory\n", MDSIO_PCI_NAME);
    err = -ENOMEM;
    goto fail1;
  }

  board->pci_dev = dev;

  // Remap configuration space and controller memory area
  board->base  = rtapi_pci_ioremap_bar(dev, 0);
  if (board->base == NULL) {
    rtapi_print_msg(RTAPI_MSG_ERR, "%s: IOREMAP failed\n", MDSIO_PCI_NAME);
    err = -ENOMEM;
    goto fail2;
  }
  rtapi_print_msg(RTAPI_MSG_INFO, "%s: Board mapped to 0x%p.\n", MDSIO_PCI_NAME, board->base);

  // create mdsio port
  port = mdsio_create_port(&mdsio_device, board);
  if (port == NULL) {
    rtapi_print_msg(RTAPI_MSG_ERR, "%s: mdsio_create_port failed\n", MDSIO_PCI_NAME);
    err = -ENOMEM;
    goto fail3;
  }
  rtapi_pci_set_drvdata(dev, port);

  return 0;

fail3:
  rtapi_iounmap(board->base);
fail2:
  rtapi_kfree(board);
fail1:
  rtapi_pci_disable_device(dev);
fail0:
  return err;
}

static void mdsio_pci_remove(struct rtapi_pci_dev *dev) {
  mdsio_port_t *port = dev->driver_data;
  mdsio_pci_board_t *board = (mdsio_pci_board_t *)(port->device_data);

  mdsio_destroy_port(port);
  rtapi_pci_set_drvdata(dev, NULL);
  rtapi_iounmap(board->base);
  rtapi_kfree(board);
  rtapi_pci_disable_device(dev);
}

static struct rtapi_pci_driver mdsio_pci_driver = {
  .name = MDSIO_PCI_NAME,
  .id_table = mdsio_pci_tbl,
  .probe = mdsio_pci_probe,
  .remove = mdsio_pci_remove,
};

int rtapi_app_main(void) {
  int err = 0;

  rtapi_print_msg(RTAPI_MSG_INFO, "%s: loading mdsIO driver version %s\n", MDSIO_PCI_NAME, MDSIO_PCI_VERSION);

  err = mdsio_init(&mdsio_device);
  if (err < 0) {
    return err;
  }

  err = rtapi_pci_register_driver(&mdsio_pci_driver);
  if (err != 0) {
    rtapi_print_msg(RTAPI_MSG_ERR, "%s: error %d registering PCI driver\n", MDSIO_PCI_NAME, err);
    mdsio_exit(&mdsio_device);
    return -EINVAL;
  }

  mdsio_ready(&mdsio_device);
  return 0;
}

void rtapi_app_exit(void) {
  rtapi_pci_unregister_driver(&mdsio_pci_driver);
  rtapi_print_msg(RTAPI_MSG_INFO, "%s: driver unloaded\n", MDSIO_PCI_NAME);
  mdsio_exit(&mdsio_device);
}

