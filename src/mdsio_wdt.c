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
#include "rtapi_string.h"

#include "hal.h"

#include "mdsio.h"
#include "mdsio_wdt.h"

static int mdsio_wdt_index = 0;

typedef struct {
  hal_bit_t *enable;
  hal_bit_t *com_error;
  hal_bit_t *reset_error;
  hal_u32_t *rand;
  uint32_t cmp_rand;
} mdsio_wdt_data_t;

int mdsio_wdt_export_pins(mdsio_mod_t *module);
void mdsio_wdt_read(mdsio_mod_t *mod, long period, uint32_t *data);
void mdsio_wdt_write(mdsio_mod_t *mod, long period, uint32_t *data);

int mdsio_wdt_init(mdsio_mod_t *module) {
  mdsio_port_t *port= module->port;
  mdsio_dev_t *device= port->device;
  mdsio_wdt_data_t *hal_data;

  // initialize module
  module->index = mdsio_wdt_index;
  module->data_len = MDSIO_WDT_LEN;
  module->proc_read = mdsio_wdt_read;
  module->proc_write = mdsio_wdt_write;
  mdsio_wdt_index++;

  if ((hal_data = hal_malloc(sizeof(mdsio_wdt_data_t))) == 0) {
    rtapi_print_msg(RTAPI_MSG_ERR, "%s.%d.wdt.%d: ERROR: hal_malloc() failed\n", device->name, port->index, module->index);
    return -EIO;
  }
  memset(hal_data, 0, sizeof(mdsio_wdt_data_t));
  module->hal_data = hal_data;

  // register pins
  if (mdsio_wdt_export_pins(module) != 0) {
    rtapi_print_msg(RTAPI_MSG_ERR, "%s.%d.wdt.%d: ERROR: export_pins() failed\n", device->name, port->index, module->index);
    return -EIO;
  }

  return 0;
}

int mdsio_wdt_export_pins(mdsio_mod_t *module) {
  mdsio_port_t *port= module->port;
  mdsio_dev_t *device= port->device;
  mdsio_wdt_data_t *data = module->hal_data;
  const char *dname = device->name;
  int comp_id = device->comp_id;
  int pidx = port->index;
  int midx = module->index;
  int err;

  if ((err = hal_pin_bit_newf(HAL_IN, &(data->enable), comp_id, "%s.%d.wdt.%d.enable", dname, pidx, midx)) != 0) {
    return err;
  }

  if ((err = hal_pin_bit_newf(HAL_OUT, &(data->com_error), comp_id, "%s.%d.wdt.%d.com-error", dname, pidx, midx)) != 0) {
    return err;
  }

  if ((err = hal_pin_bit_newf(HAL_IN, &(data->reset_error), comp_id, "%s.%d.wdt.%d.reset-error", dname, pidx, midx)) != 0) {
    return err;
  }

  if ((err = hal_pin_u32_newf(HAL_OUT, &(data->rand), comp_id, "%s.%d.wdt.%d.rand", dname, pidx, midx)) != 0) {
    return err;
  }

  // initialize data
  *(data->enable) = 0;
  *(data->com_error) = 0;
  *(data->reset_error) = 0;
  *(data->rand) = 0;

  data->cmp_rand = 0;

  return 0;
}

void mdsio_wdt_read(mdsio_mod_t *mod, long period, uint32_t *data) {
  mdsio_wdt_data_t *hal_data = mod->hal_data;
  mdsio_port_t *port= mod->port;
  mdsio_dev_t *device= port->device;
  hal_bit_t com_error;

  *(hal_data->rand) = data[0] & 0xffff;

  com_error = *(hal_data->com_error);
  if (hal_data->cmp_rand == 0 || *(hal_data->reset_error)) {
    hal_data->cmp_rand = *(hal_data->rand);
    com_error = 0;
  }

  if (*(hal_data->rand) == 0 || hal_data->cmp_rand != *(hal_data->rand)) {
    com_error = 1;
  }

  if (!(*(hal_data->com_error)) && com_error) {
    rtapi_print_msg(RTAPI_MSG_ERR, "%s.%d.wdt.%d: communication error!\n", device->name, port->index, mod->index);
  }

  *(hal_data->com_error) = com_error;
}

void mdsio_wdt_write(mdsio_mod_t *mod, long period, uint32_t *data) {
  mdsio_wdt_data_t *hal_data = mod->hal_data;

  memset(data, 0, MDSIO_WDT_LEN);

  data[0] = *(hal_data->rand) & 0xffff;

  if (*(hal_data->enable)) {
    data[0] |= (1 << 16);
  }

  hal_data->cmp_rand = (((hal_data->cmp_rand) << 1) | ((((hal_data->cmp_rand) >> 15) & 1) ^ (((hal_data->cmp_rand) >> 10) & 1))) & 0xffff;
}

