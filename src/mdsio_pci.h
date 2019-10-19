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
#ifndef _MDSIO_PCI_H_
#define _MDSIO_PCI_H_

#include <rtapi_pci.h>

#define MDSIO_PCI_VERSION "1.0.0"
#define MDSIO_PCI_NAME    "mdsio_pci"

#define MDSIO_PCI_OSC_FREQ 33333333

#define MDSIO_PCILITE_VID 0x4150
#define MDSIO_PCILITE_PID 0x0007

#define MDSIO_PCILITE_SUB_VID 0x1172
#define MDSIO_PCILITE_SUB_PID 0x0202

typedef struct mdsio_pci_board_t {
  struct rtapi_pci_dev *pci_dev;
  void rtapi__iomem *base;
} mdsio_pci_board_t;

#endif
