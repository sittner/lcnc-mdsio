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
#include "mdsio_dac.h"

static int mdsio_dac_index = 0;

typedef struct {
  hal_bit_t *pos;	// pins for output signals
  hal_bit_t *neg;	// pins for output signals
  hal_bit_t *enable;	// pin for enable signal
  hal_bit_t *absmode;	// pin for abolute mode
  hal_float_t *value;	// command value
  hal_float_t *scale;	// pin: scaling from value to duty cycle
  hal_float_t *offset;	// pin: offset: this is added to duty cycle
  double old_scale;	// stored scale value
  double scale_recip;	// reciprocal value used for scaling
  hal_float_t *min_dc;	// pin: minimum duty cycle
  hal_float_t *max_dc;	// pin: maximum duty cycle
  hal_float_t *curr_dc;	// pin: current duty cycle
} mdsio_dac_channel_data_t;

typedef struct {
  mdsio_dac_channel_data_t channels[MDSIO_DAC_CHANNELS];
} mdsio_dac_data_t;

int mdsio_dac_export_pins(mdsio_mod_t *module);
void mdsio_dac_read(mdsio_mod_t *mod, long period, uint32_t *data);
void mdsio_dac_write(mdsio_mod_t *mod, long period, uint32_t *data);

int mdsio_dac_init(mdsio_mod_t *module) {
  mdsio_port_t *port= module->port;
  mdsio_dev_t *device= port->device;
  mdsio_dac_data_t *hal_data;

  // initialize module
  module->index = mdsio_dac_index;
  module->data_len = MDSIO_DAC_LEN;
  module->proc_read = mdsio_dac_read;
  module->proc_write = mdsio_dac_write;
  mdsio_dac_index++;

  if ((hal_data = hal_malloc(sizeof(mdsio_dac_data_t))) == 0) {
    rtapi_print_msg(RTAPI_MSG_ERR, "%s.%d.dac.%d: ERROR: hal_malloc() failed\n", device->name, port->index, module->index);
    return -EIO;
  }
  memset(hal_data, 0, sizeof(mdsio_dac_data_t));
  module->hal_data = hal_data;

  // register pins
  if (mdsio_dac_export_pins(module) != 0) {
    rtapi_print_msg(RTAPI_MSG_ERR, "%s.%d.dac.%d: ERROR: export_pins() failed\n", device->name, port->index, module->index);
    return -EIO;
  }

  return 0;
}

int mdsio_dac_export_pins(mdsio_mod_t *module) {
  mdsio_port_t *port= module->port;
  mdsio_dev_t *device= port->device;
  mdsio_dac_data_t *module_data = module->hal_data;
  mdsio_dac_channel_data_t *data;
  const char *dname = device->name;
  int comp_id = device->comp_id;
  int pidx = port->index;
  int midx = module->index;
  int err;
  int i;

  for(i=0; i<MDSIO_DAC_CHANNELS; i++) {
    data = &(module_data->channels[i]);

    // export paramameters
    if ((err = hal_pin_float_newf(HAL_IO, &(data->scale), comp_id, "%s.%d.dac.%d.ch%d-scale", dname, pidx, midx, i)) != 0) {
      return err;
    }
    if ((err = hal_pin_float_newf(HAL_IO, &(data->offset), comp_id, "%s.%d.dac.%d.ch%d-offset", dname, pidx, midx, i)) != 0) {
      return err;
    }
    if ((err = hal_pin_float_newf(HAL_IO, &(data->min_dc), comp_id, "%s.%d.dac.%d.ch%d-min-dc", dname, pidx, midx, i)) != 0) {
      return err;
    }
    if ((err = hal_pin_float_newf(HAL_IO, &(data->max_dc), comp_id, "%s.%d.dac.%d.ch%d-max-dc", dname, pidx, midx, i)) != 0) {
      return err;
    }
    if ((err = hal_pin_float_newf(HAL_OUT, &(data->curr_dc), comp_id, "%s.%d.dac.%d.ch%d-curr-dc", dname, pidx, midx, i)) != 0) {
      return err;
    }

    // export pins
    if ((err = hal_pin_bit_newf(HAL_IN, &(data->enable), comp_id, "%s.%d.dac.%d.ch%d-enable", dname, pidx, midx, i)) != 0) {
      return err;
    }
    if ((err = hal_pin_bit_newf(HAL_IN, &(data->absmode), comp_id, "%s.%d.dac.%d.ch%d-absmode", dname, pidx, midx, i)) != 0) {
      return err;
    }
    if ((err = hal_pin_float_newf(HAL_IN, &(data->value), comp_id, "%s.%d.dac.%d.ch%d-value", dname, pidx, midx, i)) != 0) {
      return err;
    }

    // export UP/DOWN pins
    if ((err = hal_pin_bit_newf(HAL_OUT, &(data->pos), comp_id, "%s.%d.dac.%d.ch%d-pos", dname, pidx, midx, i)) != 0) {
      return err;
    }
    if ((err = hal_pin_bit_newf(HAL_OUT, &(data->neg), comp_id, "%s.%d.dac.%d.ch%d-neg", dname, pidx, midx, i)) != 0) {
      return err;
    }

    // set default pin values
    *(data->scale) = 1.0;
    *(data->offset) = 0.0;
    *(data->min_dc) = -1.0;
    *(data->max_dc) = 1.0;
    *(data->curr_dc) = 0.0;
    *(data->enable) = 0;
    *(data->absmode) = 0;
    *(data->value) = 0.0;
    *(data->pos) = 0;
    *(data->neg) = 0;

    // init other fields
    data->old_scale = *(data->scale) + 1.0;
  }

  return 0;
}

void mdsio_dac_read(mdsio_mod_t *mod, long period, uint32_t *data) {
  // this module is output only
}

void mdsio_dac_write(mdsio_mod_t *mod, long period, uint32_t *data) {
  mdsio_dac_data_t *module_data = mod->hal_data;
  mdsio_dac_channel_data_t *hal_data;
  int i, word;
  double tmpval, tmpdc;
  int32_t dac_val;

  memset(data, 0, MDSIO_DAC_LEN);

  for (i=0; i<MDSIO_DAC_CHANNELS; i++) {
    hal_data = &(module_data->channels[i]);

    // validate duty cycle limits, both limits must be between
    // 0.0 and 1.0 (inclusive) and max must be greater then min
    if (*(hal_data->max_dc) > 1.0) {
      *(hal_data->max_dc) = 1.0;
    }
    if (*(hal_data->min_dc) > *(hal_data->max_dc)) {
      *(hal_data->min_dc) = *(hal_data->max_dc);
    }
    if (*(hal_data->min_dc) < -1.0) {
      *(hal_data->min_dc) = -1.0;
    }
    if (*(hal_data->max_dc) < *(hal_data->min_dc)) {
      *(hal_data->max_dc) = *(hal_data->min_dc);
    }

    // do scale calcs only when scale changes
    if (*(hal_data->scale) != hal_data->old_scale) {
      // validate the new scale value
      if ((*(hal_data->scale) < 1e-20) && (*(hal_data->scale) > -1e-20)) {
        // value too small, divide by zero is a bad thing
        *(hal_data->scale) = 1.0;
      }
      // get ready to detect future scale changes
      hal_data->old_scale = *(hal_data->scale);
      // we will need the reciprocal
      hal_data->scale_recip = 1.0 / *(hal_data->scale);
    }

    // get command
    tmpval = *(hal_data->value);
    if (*(hal_data->absmode) && (tmpval < 0)) {
      tmpval = -tmpval;
    }

    // convert value command to duty cycle
    tmpdc = tmpval * hal_data->scale_recip + *(hal_data->offset);
    if (tmpdc < *(hal_data->min_dc)) {
      tmpdc = *(hal_data->min_dc);
    }
    if (tmpdc > *(hal_data->max_dc)) {
      tmpdc = *(hal_data->max_dc);
    }

    // set output values
    if (*(hal_data->enable) == 0) {
      dac_val = 0x8000;
      *(hal_data->pos) = 0;
      *(hal_data->neg) = 0;
      *(hal_data->curr_dc) = 0;
    } else {
      dac_val = 0x8000 + ((double)0x7fff * tmpdc);
      if (dac_val < 0x0000) {
        dac_val = 0x0000;
      }
      if (dac_val > 0xffff) {
        dac_val = 0xffff;
      }
      *(hal_data->pos) = (*(hal_data->value) > 0);
      *(hal_data->neg) = (*(hal_data->value) < 0);
      *(hal_data->curr_dc) = tmpdc;
    }

    word = i >> 1;
    if ((i & 0x01) == 0) {
      data[word] = dac_val;
    } else {
      data[word] |= dac_val << 16;
    }
  }
}

