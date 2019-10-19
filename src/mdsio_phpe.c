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

#include <float.h>

#include "rtapi.h"
#include "rtapi_string.h"
#include "rtapi_math.h"

#include "hal.h"

#include "mdsio.h"
#include "mdsio_phpe.h"

static int mdsio_phpe_index = 0;

typedef struct {
  hal_s32_t *raw_counts;
  hal_float_t *sin;
  hal_float_t *cos;
  hal_float_t *lores;
  hal_float_t *hires;
  hal_float_t *level;
  hal_bit_t *level_warn;
  hal_bit_t *level_err;
  hal_float_t *raw_pos;
  hal_float_t *flt_pos;
  hal_float_t *pos;
  hal_bit_t *area_state;
  hal_bit_t *area_ena;
  hal_float_t *area_pos;
  hal_bit_t area_inv;
  hal_bit_t pos_inv;
  int area_init;
} mdsio_phpe_channel_data_t;

typedef struct {
  hal_float_t level_warn_val;
  hal_float_t level_err_val;
  hal_float_t array_len;
  hal_u32_t array_cnt;
  hal_u32_t array_cnt_old;
  hal_u32_t time_top;
  hal_u32_t time_scan;
  hal_u32_t time_disch;
  hal_u32_t time_take;
  double factor_ns;
  double factor_sincos;
  mdsio_phpe_channel_data_t channels[MDSIO_PHPE_CHANNELS];
} mdsio_phpe_data_t;

int mdsio_phpe_export_pins(mdsio_mod_t *module);
void mdsio_phpe_read(mdsio_mod_t *mod, long period, uint32_t *data);
void mdsio_phpe_write(mdsio_mod_t *mod, long period, uint32_t *data);

int mdsio_phpe_init(mdsio_mod_t *module) {
  mdsio_port_t *port= module->port;
  mdsio_dev_t *device= port->device;
  mdsio_phpe_data_t *hal_data;

  // initialize module
  module->index = mdsio_phpe_index;
  module->data_len = MDSIO_PHPE_LEN;
  module->proc_read = mdsio_phpe_read;
  module->proc_write = mdsio_phpe_write;
  mdsio_phpe_index++;

  if ((hal_data = hal_malloc(sizeof(mdsio_phpe_data_t))) == 0) {
    rtapi_print_msg(RTAPI_MSG_ERR, "%s.%d.phpe.%d: ERROR: hal_malloc() failed\n", device->name, port->index, module->index);
    return -EIO;
  }
  memset(hal_data, 0, sizeof(mdsio_phpe_data_t));
  module->hal_data = hal_data;

  // calculate time constants
  hal_data->factor_ns = (double)device->osc_freq / (double)1000000000;

  // level check
  hal_data->level_warn_val = 0;
  hal_data->level_err_val  = 0;

  // array parameters
  hal_data->array_len = 0.635;
  hal_data->array_cnt = 10;

  // timing parameters
  hal_data->time_top   = 42000;
  hal_data->time_scan  = 28400;
  hal_data->time_disch = 28600;
  hal_data->time_take  = 28200;

  // register pins
  if (mdsio_phpe_export_pins(module) != 0) {
    rtapi_print_msg(RTAPI_MSG_ERR, "%s.%d.phpe.%d: ERROR: export_pins() failed\n", device->name, port->index, module->index);
    return -EIO;
  }

  return 0;
}

int mdsio_phpe_export_pins(mdsio_mod_t *module) {
  mdsio_port_t *port= module->port;
  mdsio_dev_t *device= port->device;
  mdsio_phpe_data_t *module_data = module->hal_data;
  mdsio_phpe_channel_data_t *data;
  const char *dname = device->name;
  int comp_id = device->comp_id;
  int pidx = port->index;
  int midx = module->index;
  int err;
  int i;

  if ((err = hal_param_float_newf(HAL_RW, &(module_data->level_warn_val), comp_id, "%s.%d.phpe.%d.level-warn-val", dname, pidx, midx)) != 0) {
    return err;
  }
  if ((err = hal_param_float_newf(HAL_RW, &(module_data->level_err_val), comp_id, "%s.%d.phpe.%d.level-err-val", dname, pidx, midx)) != 0) {
    return err;
  }
  if ((err = hal_param_float_newf(HAL_RW, &(module_data->array_len), comp_id, "%s.%d.phpe.%d.array-len", dname, pidx, midx)) != 0) {
    return err;
  }
  if ((err = hal_param_u32_newf(HAL_RW, &(module_data->array_cnt), comp_id, "%s.%d.phpe.%d.array-cnt", dname, pidx, midx)) != 0) {
    return err;
  }
  if ((err = hal_param_u32_newf(HAL_RW, &(module_data->time_top), comp_id, "%s.%d.phpe.%d.time-top", dname, pidx, midx)) != 0) {
    return err;
  }
  if ((err = hal_param_u32_newf(HAL_RW, &(module_data->time_scan), comp_id, "%s.%d.phpe.%d.time-scan", dname, pidx, midx)) != 0) {
    return err;
  }
  if ((err = hal_param_u32_newf(HAL_RW, &(module_data->time_disch), comp_id, "%s.%d.phpe.%d.time-disch", dname, pidx, midx)) != 0) {
    return err;
  }
  if ((err = hal_param_u32_newf(HAL_RW, &(module_data->time_take), comp_id, "%s.%d.phpe.%d.time-take", dname, pidx, midx)) != 0) {
    return err;
  }

  // init other fields
  module_data->array_cnt_old = 0;
  module_data->factor_sincos = 0;

  for(i=0; i<MDSIO_PHPE_CHANNELS; i++) {
    data = &(module_data->channels[i]);

    if ((err = hal_pin_s32_newf(HAL_OUT, &(data->raw_counts), comp_id, "%s.%d.phpe.%d.ch%d-raw-counts", dname, pidx, midx, i)) != 0) {
      return err;
    }
    if ((err = hal_pin_float_newf(HAL_OUT, &(data->sin), comp_id, "%s.%d.phpe.%d.ch%d-sin", dname, pidx, midx, i)) != 0) {
      return err;
    }
    if ((err = hal_pin_float_newf(HAL_OUT, &(data->cos), comp_id, "%s.%d.phpe.%d.ch%d-cos", dname, pidx, midx, i)) != 0) {
      return err;
    }
    if ((err = hal_pin_float_newf(HAL_OUT, &(data->lores), comp_id, "%s.%d.phpe.%d.ch%d-lores", dname, pidx, midx, i)) != 0) {
      return err;
    }
    if ((err = hal_pin_float_newf(HAL_OUT, &(data->hires), comp_id, "%s.%d.phpe.%d.ch%d-hires", dname, pidx, midx, i)) != 0) {
      return err;
    }
    if ((err = hal_pin_float_newf(HAL_OUT, &(data->level), comp_id, "%s.%d.phpe.%d.ch%d-level", dname, pidx, midx, i)) != 0) {
      return err;
    }
    if ((err = hal_pin_bit_newf(HAL_OUT, &(data->level_warn), comp_id, "%s.%d.phpe.%d.ch%d-level-warn", dname, pidx, midx, i)) != 0) {
      return err;
    }
    if ((err = hal_pin_bit_newf(HAL_OUT, &(data->level_err), comp_id, "%s.%d.phpe.%d.ch%d-level-err", dname, pidx, midx, i)) != 0) {
      return err;
    }
    if ((err = hal_pin_float_newf(HAL_OUT, &(data->raw_pos), comp_id, "%s.%d.phpe.%d.ch%d-raw-pos", dname, pidx, midx, i)) != 0) {
      return err;
    }
    if ((err = hal_pin_float_newf(HAL_OUT, &(data->flt_pos), comp_id, "%s.%d.phpe.%d.ch%d-flt-pos", dname, pidx, midx, i)) != 0) {
      return err;
    }
    if ((err = hal_pin_float_newf(HAL_OUT, &(data->pos), comp_id, "%s.%d.phpe.%d.ch%d-pos", dname, pidx, midx, i)) != 0) {
      return err;
    }
    if ((err = hal_pin_bit_newf(HAL_OUT, &(data->area_state), comp_id, "%s.%d.phpe.%d.ch%d-area-state", dname, pidx, midx, i)) != 0) {
      return err;
    }
    if ((err = hal_pin_bit_newf(HAL_IO, &(data->area_ena), comp_id, "%s.%d.phpe.%d.ch%d-area-ena", dname, pidx, midx, i)) != 0) {
      return err;
    }
    if ((err = hal_pin_float_newf(HAL_OUT, &(data->area_pos), comp_id, "%s.%d.phpe.%d.ch%d-area-pos", dname, pidx, midx, i)) != 0) {
      return err;
    }
    if ((err = hal_param_bit_newf(HAL_RW, &(data->area_inv), comp_id, "%s.%d.phpe.%d.ch%d-area-inv", dname, pidx, midx, i)) != 0) {
      return err;
    }
    if ((err = hal_param_bit_newf(HAL_RW, &(data->pos_inv), comp_id, "%s.%d.phpe.%d.ch%d-pos-inv", dname, pidx, midx, i)) != 0) {
      return err;
    }

    // set default pin values
    *(data->raw_counts) = 0;
    *(data->sin) = 0.0;
    *(data->cos) = 0.0;
    *(data->lores) = 0.0;
    *(data->hires) = 0.0;
    *(data->level) = 0.0;
    *(data->level_warn) = 0;
    *(data->level_err) = 0;
    *(data->raw_pos) = 0.0;
    *(data->pos) = 0.0;
    *(data->area_state) = 0;
    *(data->area_ena) = 0;
    *(data->area_pos) = 0.0;

    // init other fields
    data->area_inv = 0;
    data->pos_inv = 0;
    data->area_init = 1;
  }

  return 0;
}

void mdsio_phpe_read(mdsio_mod_t *mod, long period, uint32_t *data) {
  mdsio_phpe_data_t *module_data = mod->hal_data;
  mdsio_phpe_channel_data_t *hal_data;
  int i, word, bit;
  int32_t raw_cnt, raw_sin, raw_cos, int_pos;
  double lores, sin, cos, level, cosphi, hires, pos;
  hal_bit_t area_flag;

  // calculate sincos factor
  if (module_data->factor_sincos == 0 || module_data->array_cnt != module_data->array_cnt_old) {
    module_data->array_cnt_old = module_data->array_cnt;
    module_data->factor_sincos = 1 / (double)(module_data->array_cnt << 16);
  }

  for (i=0, word=3, bit=0; i<MDSIO_PHPE_CHANNELS; i++, word+=6, bit+=8) {
    hal_data = &(module_data->channels[i]);

    // get bit flags
    *(hal_data->area_state) = (data[0] >> (bit + 1)) & 0x1;
    area_flag = (data[0] >> (bit + 2)) & 0x1;

    // handle area flag
    if (area_flag && *(hal_data->area_ena)) {
      *(hal_data->area_ena) = 0;

      // read area registers
      raw_cnt = data[word + 3];
      raw_sin = data[word + 4];
      raw_cos = data[word + 5];

      // calculate lores part
      lores = (double)raw_cnt * module_data->array_len;

      // get sin/cos values
      sin = (double)raw_sin * module_data->factor_sincos;
      cos = (double)raw_cos * module_data->factor_sincos;

      // calculate level
      level = sqrt(sin*sin + cos*cos);

      // calculate cosine phi
      if (level != 0) {
        cosphi = cos / level;
      } else {
        cosphi = 1;
      }

      // calulate hires part
      hires = acos(cosphi) / (2*M_PI) * module_data->array_len;
      if (sin < 0) hires = -hires;
 
      // calc position
      pos = lores+hires;

      // invert position
      if (hal_data->pos_inv) {
        pos = -pos;
      }

      // set position
      *(hal_data->area_pos) = pos;
    }

    // read registers
    raw_cnt = data[word + 0];
    raw_sin = data[word + 1];
    raw_cos = data[word + 2];

    // calculate lores part
    lores = (double)raw_cnt * module_data->array_len;

    // get sin/cos values
    sin = (double)raw_sin * module_data->factor_sincos;
    cos = (double)raw_cos * module_data->factor_sincos;

    // calculate level
    level = sqrt(sin*sin + cos*cos);

    // calculate cosine phi
    if (level != 0) {
      cosphi = cos / level;
    } else {
      cosphi = 1;
    }

    // calulate hires part
    hires = acos(cosphi) / (2*M_PI) * module_data->array_len;
    if (sin < 0) hires = -hires;
 
    // calc position
    pos = lores+hires;

    // invert position
    if (hal_data->pos_inv) {
      pos = -pos;
    }

    // update pins
    *(hal_data->raw_counts) = raw_cnt;
    *(hal_data->lores) = lores;
    *(hal_data->sin) = sin;
    *(hal_data->cos) = cos;
    *(hal_data->level) = level;
    *(hal_data->hires) = hires;
    *(hal_data->raw_pos) = pos;

    // filter pos
    if (fabs(*(hal_data->flt_pos) - pos) > 0.0005) {
      int_pos = (int32_t)(pos * 1000);
      *(hal_data->flt_pos) = (double)int_pos * 0.001;
    }

    // calculate area offset
    *(hal_data->pos) = *(hal_data->flt_pos) - *(hal_data->area_pos);

    // check level
    *(hal_data->level_warn) = (module_data->level_warn_val > 0 && level < module_data->level_warn_val);
    *(hal_data->level_err) = (module_data->level_err_val > 0 && level < module_data->level_err_val);
  }
}

void mdsio_phpe_write(mdsio_mod_t *mod, long period, uint32_t *data) {
  mdsio_phpe_data_t *module_data = mod->hal_data;
  mdsio_phpe_channel_data_t *hal_data;
  uint32_t top, scan, disch, take;
  int i, bit;

  memset(data, 0, MDSIO_PHPE_LEN);
 
  // calculate timing periods
  top   = (uint32_t)(module_data->factor_ns * (double)module_data->time_top);
  scan  = (uint32_t)(module_data->factor_ns * (double)module_data->time_scan);
  disch = (uint32_t)(module_data->factor_ns * (double)module_data->time_disch);
  take  = (uint32_t)(module_data->factor_ns * (double)module_data->time_take);

  // write timing registers
  data[1] = (top & 0xffff) | ((scan & 0xffff) << 16);
  data[2] = (disch & 0xffff) | ((take & 0xffff) << 16);

  for (i=0, bit=0; i<MDSIO_PHPE_CHANNELS; i++, bit+=8) {
    hal_data = &(module_data->channels[i]);

    // set bit flags
    if (hal_data->area_inv) {
      data[0] |= (1 << (bit + 0));
    }
  }
}

