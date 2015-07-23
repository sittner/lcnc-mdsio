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

#include <linux/ctype.h>

#include "rtapi.h"
#include "rtapi_string.h"

#include "hal.h"

#include "mdsio.h"
#include "mdsio_dio.h"

static int mdsio_dio_index = 0;

typedef struct {
  hal_bit_t *input_pins[MDSIO_DIO_PINS];
  hal_bit_t *input_pins_not[MDSIO_DIO_PINS];
  hal_bit_t *input_error;
  hal_bit_t *input_error_reset;
  hal_bit_t *output_pins[MDSIO_DIO_PINS];
  hal_bit_t output_pins_inv[MDSIO_DIO_PINS];
  hal_bit_t *output_error;
  hal_bit_t *output_error_reset;
  hal_bit_t *output_fault;
  hal_bit_t *output_fault_reset;
} mdsio_dio_data_t;

int mdsio_dio_export_pins(mdsio_mod_t *module);
void mdsio_dio_read(mdsio_mod_t *mod, long period, uint32_t *data);
void mdsio_dio_write(mdsio_mod_t *mod, long period, uint32_t *data);

int mdsio_dio_init(mdsio_mod_t *module) {
  mdsio_port_t *port= module->port;
  mdsio_dev_t *device= port->device;
  mdsio_dio_data_t *hal_data;

  // initialize module
  module->index = mdsio_dio_index;
  module->data_len = MDSIO_DIO_LEN;
  module->proc_read = mdsio_dio_read;
  module->proc_write = mdsio_dio_write;
  mdsio_dio_index++;

  if ((hal_data = hal_malloc(sizeof(mdsio_dio_data_t))) == 0) {
    rtapi_print_msg(RTAPI_MSG_ERR, "%s.%d.dio.%d: ERROR: hal_malloc() failed\n", device->name, port->index, module->index);
    return -EIO;
  }
  memset(hal_data, 0, sizeof(mdsio_dio_data_t));
  module->hal_data = hal_data;

  // register pins
  if (mdsio_dio_export_pins(module) != 0) {
    rtapi_print_msg(RTAPI_MSG_ERR, "%s.%d.dio.%d: ERROR: export_pins() failed\n", device->name, port->index, module->index);
    return -EIO;
  }

  return 0;
}

int mdsio_dio_export_pins(mdsio_mod_t *module) {
  mdsio_port_t *port= module->port;
  mdsio_dev_t *device= port->device;
  mdsio_dio_data_t *data = module->hal_data;
  const char *dname = device->name;
  int comp_id = device->comp_id;
  int pidx = port->index;
  int midx = module->index;
  int err;
  int i;

  if ((err = hal_pin_bit_newf(HAL_OUT, &(data->input_error), comp_id, "%s.%d.dio.%d.input-error", dname, pidx, midx)) != 0) {
    return err;
  }
  if ((err = hal_pin_bit_newf(HAL_IN, &(data->input_error_reset), comp_id, "%s.%d.dio.%d.input-error-reset", dname, pidx, midx)) != 0) {
    return err;
  }
  *(data->input_error) = 0;
  *(data->input_error_reset) = 0;

  if ((err = hal_pin_bit_newf(HAL_OUT, &(data->output_error), comp_id, "%s.%d.dio.%d.output-error", dname, pidx, midx)) != 0) {
    return err;
  }
  if ((err = hal_pin_bit_newf(HAL_IN, &(data->output_error_reset), comp_id, "%s.%d.dio.%d.output-error-reset", dname, pidx, midx)) != 0) {
    return err;
  }
  *(data->output_error) = 0;
  *(data->output_error_reset) = 0;

  if ((err = hal_pin_bit_newf(HAL_OUT, &(data->output_fault), comp_id, "%s.%d.dio.%d.output-fault", dname, pidx, midx)) != 0) {
    return err;
  }
  if ((err = hal_pin_bit_newf(HAL_IN, &(data->output_fault_reset), comp_id, "%s.%d.dio.%d.output-fault-reset", dname, pidx, midx)) != 0) {
    return err;
  }
  *(data->output_fault) = 0;
  *(data->output_fault_reset) = 0;

  for (i=0; i<MDSIO_DIO_PINS; i++) {
    if ((err = hal_pin_bit_newf(HAL_OUT, &(data->input_pins[i]), comp_id, "%s.%d.dio.%d.din-%02d", dname, pidx, midx, i)) != 0) {
      return err;
    }
    if ((err = hal_pin_bit_newf(HAL_OUT, &(data->input_pins_not[i]), comp_id, "%s.%d.dio.%d.din-%02d-not", dname, pidx, midx, i)) != 0) {
      return err;
    }
    *(data->input_pins[i]) = 0;
    *(data->input_pins_not[i]) = 0;

    if ((err = hal_pin_bit_newf(HAL_IN, &(data->output_pins[i]), comp_id, "%s.%d.dio.%d.dout-%02d", dname, pidx, midx, i)) != 0) {
      return err;
    }
    if ((err = hal_param_bit_newf(HAL_RW, &(data->output_pins_inv[i]), comp_id, "%s.%d.dio.%d.dout-%02d-invert", dname, pidx, midx, i)) != 0) {
      return err;
    }
    *(data->output_pins[i]) = 0;
    data->output_pins_inv[i] = 0;
  }

  return 0;
}

void mdsio_dio_read(mdsio_mod_t *mod, long period, uint32_t *data) {
  mdsio_dio_data_t *hal_data = mod->hal_data;
  mdsio_port_t *port= mod->port;
  mdsio_dev_t *device= port->device;
  uint32_t reg;
  int i, word, bit;
  hal_bit_t error_pin;

  for (i=0; i<MDSIO_DIO_PINS; i++) {
    word = i >> 5;
    bit = i & 0x1f;

    reg = (data[word] >> bit) & 0x01;
    *(hal_data->input_pins[i]) = reg;
    *(hal_data->input_pins_not[i]) = !reg;
  }

  reg = data[1];

  error_pin = (reg >> 18) & 0x01;
  if (!(*(hal_data->input_error)) && error_pin) {
    rtapi_print_msg(RTAPI_MSG_ERR, "%s.%d.dio.%d: input communication error!\n", device->name, port->index, mod->index);
  }
  *(hal_data->input_error) = error_pin;

  error_pin = (reg >> 17) & 0x01;
  if (!(*(hal_data->output_error)) && error_pin) {
    rtapi_print_msg(RTAPI_MSG_ERR, "%s.%d.dio.%d: output communication error!\n", device->name, port->index, mod->index);
  }
  *(hal_data->output_error) = error_pin;

  error_pin = (reg >> 16) & 0x01;
  if (!(*(hal_data->output_fault)) && error_pin) {
    rtapi_print_msg(RTAPI_MSG_ERR, "%s.%d.dio.%d: output fault!\n", device->name, port->index, mod->index);
  }
  *(hal_data->output_fault) = error_pin;
}

void mdsio_dio_write(mdsio_mod_t *mod, long period, uint32_t *data) {
  mdsio_dio_data_t *hal_data = mod->hal_data;
  uint32_t reg;
  int i, word, bit;
  hal_bit_t state;
  
  memset(data, 0, MDSIO_DIO_LEN);

  for (i=0; i<MDSIO_DIO_PINS; i++) {
    word = i >> 5;
    bit = i & 0x1f;

    state = *(hal_data->output_pins[i]);
    if (hal_data->output_pins_inv[i]) {
      state = !state;
    }
    if (state) {
      data[word] |= (1 << bit);
    }
  }

  reg = data[1] & 0x0000ffff;
  if(*(hal_data->input_error_reset)) {
    reg |= (1 << 18);
  }
  if(*(hal_data->output_error_reset)) {
    reg |= (1 << 17);
  }
  if(*(hal_data->output_fault_reset)) {
    reg |= (1 << 16);
  }
  data[1] = reg;
}

