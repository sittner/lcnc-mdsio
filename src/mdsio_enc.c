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
#include "mdsio_enc.h"

static int mdsio_enc_index = 0;

typedef struct {
  int do_init;
  hal_s32_t *raw_counts;	// u:rw raw count value, in update() only
  hal_bit_t *index_ena;		// c:rw index enable input
  hal_bit_t *reset;		// c:r counter reset input
  int32_t exp_count;		// u:rw stored raw_count for width expansion
  int32_t raw_count;		// c:rw captured raw_count
  uint32_t timestamp;		// c:rw captured timestamp
  int32_t index_count;		// c:rw captured index count
  hal_s32_t *count;		// c:w captured binary count value
  hal_float_t *pos;		// c:w scaled position (floating point)
  hal_float_t *pos_interp;	// c:w scaled and interpolated position (float)
  hal_float_t *vel;		// c:w scaled velocity (floating point)
  hal_float_t *pos_scale;	// c:r pin: scaling factor for pos
  double old_scale;		// c:rw stored scale value
  double scale;			// c:rw reciprocal value used for scaling
  int counts_since_timeout;	// c:rw used for velocity calcs
} mdsio_enc_channel_data_t;

typedef struct {
  hal_float_t timeout;		// c:rw timeout for vel in sec. (floating point)
  mdsio_enc_channel_data_t channels[MDSIO_ENC_CHANNELS];
} mdsio_enc_data_t;

int mdsio_enc_export_pins(mdsio_mod_t *module);
void mdsio_enc_read(mdsio_mod_t *mod, long period, uint32_t *data);
void mdsio_enc_write(mdsio_mod_t *mod, long period, uint32_t *data);

int mdsio_enc_init(mdsio_mod_t *module) {
  mdsio_port_t *port= module->port;
  mdsio_dev_t *device= port->device;
  mdsio_enc_data_t *hal_data;

  // initialize module
  module->index = mdsio_enc_index;
  module->data_len = MDSIO_ENC_LEN;
  module->proc_read = mdsio_enc_read;
  module->proc_write = mdsio_enc_write;
  mdsio_enc_index++;

  if ((hal_data = hal_malloc(sizeof(mdsio_enc_data_t))) == 0) {
    rtapi_print_msg(RTAPI_MSG_ERR, "%s.%d.enc.%d: ERROR: hal_malloc() failed\n", device->name, port->index, module->index);
    return -EIO;
  }
  memset(hal_data, 0, sizeof(mdsio_enc_data_t));
  module->hal_data = hal_data;

  // register pins
  if (mdsio_enc_export_pins(module) != 0) {
    rtapi_print_msg(RTAPI_MSG_ERR, "%s.%d.enc.%d: ERROR: export_pins() failed\n", device->name, port->index, module->index);
    return -EIO;
  }

  return 0;
}

int mdsio_enc_export_pins(mdsio_mod_t *module) {
  mdsio_port_t *port= module->port;
  mdsio_dev_t *device= port->device;
  mdsio_enc_data_t *module_data = module->hal_data;
  mdsio_enc_channel_data_t *data;
  const char *dname = device->name;
  int comp_id = device->comp_id;
  int pidx = port->index;
  int midx = module->index;
  int err;
  int i;

  // export pin for timeout
  if ((err = hal_param_float_newf(HAL_RW, &(module_data->timeout), comp_id, "%s.%d.enc.%d.timeout", dname, pidx, midx)) != 0) {
    return err;
  }
  module_data->timeout = 0.1;

  for(i=0; i<MDSIO_ENC_CHANNELS; i++) {
    data = &(module_data->channels[i]);

    // export pin for the index enable input
    if ((err = hal_pin_bit_newf(HAL_IO, &(data->index_ena), comp_id, "%s.%d.enc.%d.ch%d-index-enable", dname, pidx, midx, i)) != 0) {
      return err;
    }
    // export pin for the reset input
    if ((err = hal_pin_bit_newf(HAL_IN, &(data->reset), comp_id, "%s.%d.enc.%d.ch%d-reset", dname, pidx, midx, i)) != 0) {
      return err;
    }
    // export parameter for raw counts
    if ((err = hal_pin_s32_newf(HAL_OUT, &(data->raw_counts), comp_id, "%s.%d.enc.%d.ch%d-raw", dname, pidx, midx, i)) != 0) {
      return err;
    }
    // export pin for counts captured
    if ((err = hal_pin_s32_newf(HAL_OUT, &(data->count), comp_id, "%s.%d.enc.%d.ch%d-counts", dname, pidx, midx, i)) != 0) {
      return err;
    }
    // export pin for scaled position captured
    if ((err = hal_pin_float_newf(HAL_OUT, &(data->pos), comp_id, "%s.%d.enc.%d.ch%d-pos", dname, pidx, midx, i)) != 0) {
      return err;
    }
    // export pin for scaled and interpolated position captured
    if ((err = hal_pin_float_newf(HAL_OUT, &(data->pos_interp), comp_id, "%s.%d.enc.%d.ch%d-pos-ipol", dname, pidx, midx, i)) != 0) {
      return err;
    }
    // export pin for scaled velocity captured
    if ((err = hal_pin_float_newf(HAL_OUT, &(data->vel), comp_id, "%s.%d.enc.%d.ch%d-velo", dname, pidx, midx, i)) != 0) {
      return err;
    }
    // export pin for scaling
    if ((err = hal_pin_float_newf(HAL_IO, &(data->pos_scale), comp_id, "%s.%d.enc.%d.ch%d-pos-scale", dname, pidx, midx, i)) != 0) {
      return err;
    }

    // set default pin values
    *(data->raw_counts) = 0;
    *(data->count) = 0;
    *(data->pos) = 0.0;
    *(data->vel) = 0.0;
    *(data->pos_scale) = 1.0;

    // init other fields
    data->do_init = 1;
    data->exp_count = 0;
    data->raw_count = 0;
    data->timestamp = 0;
    data->index_count = 0;
    data->old_scale = *(data->pos_scale) + 1.0;
    data->scale = 1.0;
    data->counts_since_timeout = 0;
  }

  return 0;
}

void mdsio_enc_read(mdsio_mod_t *mod, long period, uint32_t *data) {
  mdsio_enc_data_t *module_data = mod->hal_data;
  mdsio_port_t *port= mod->port;
  mdsio_dev_t *device= port->device;
  mdsio_enc_channel_data_t *hal_data;
  int i, word;
  uint32_t timeout;
  uint32_t timebase, timestamp, delta_time;
  int32_t raw_count, idx_count, delta_counts;
  uint32_t cnt_flag, idx_flag;
  double vel, interp;

  // read timebase
  word = 0;
  timebase = data[word++];

  // calculate timeout
  timeout = (uint32_t)((double)(device->osc_freq) * module_data->timeout);
  
  for (i=0; i<MDSIO_ENC_CHANNELS; i++) {
    hal_data = &(module_data->channels[i]);

    // check for change in scale value
    if (*(hal_data->pos_scale) != hal_data->old_scale) {
      // scale value has changed, test and update it
      if ((*(hal_data->pos_scale) < 1e-20) && (*(hal_data->pos_scale) > -1e-20)) {
        // value too small, divide by zero is a bad thing
        *(hal_data->pos_scale) = 1.0;
      }
      // save new scale to detect future changes
      hal_data->old_scale = *(hal_data->pos_scale);
      // we actually want the reciprocal
      hal_data->scale = 1.0 / *(hal_data->pos_scale);
    }

    // read hw data
    cnt_flag = data[word++];
    timestamp = data[word++];
    idx_flag = data[word++];

    // expand counter width to 32 bit
    raw_count = hal_data->exp_count + ((((int32_t)(cnt_flag << 1)) - (hal_data->exp_count << 1)) >> 1);
    idx_count = hal_data->exp_count + ((((int32_t)(idx_flag << 1)) - (hal_data->exp_count << 1)) >> 1);
    hal_data->exp_count = raw_count;    

    // get flags
    cnt_flag = cnt_flag  >> 31;
    idx_flag = cnt_flag  >> 31;

    // update raw count
    *(hal_data->raw_counts) = raw_count;

    // handle initialization
    if (hal_data->do_init || *(hal_data->reset)) {
      hal_data->do_init = 0;
      hal_data->raw_count = raw_count;
      hal_data->index_count = raw_count;
      cnt_flag = 0;
      idx_flag = 0;
    }

    // handle index
    if (idx_flag && *(hal_data->index_ena)) {
      hal_data->index_count = idx_count;
      *(hal_data->index_ena) = 0;
    }

    // calculate vel
    if (cnt_flag) {
      // one or more counts in the last period
      delta_counts = raw_count - hal_data->raw_count;
      delta_time = timestamp - hal_data->timestamp;
      hal_data->raw_count = raw_count;
      hal_data->timestamp = timestamp;
      if (hal_data->counts_since_timeout < 2) {
        hal_data->counts_since_timeout++;
      } else {
        vel = (delta_counts * hal_data->scale) / ((double)delta_time / (double)(device->osc_freq));
        *(hal_data->vel) = vel;
      }
    } else {
      // no count
      if (hal_data->counts_since_timeout) {
        // calc time since last count
        delta_time = timebase - hal_data->timestamp;
        if (delta_time < timeout) {
          // not to long, estimate vel if a count arrived now
          vel = (hal_data->scale) / ((double)delta_time / (double)(device->osc_freq));
          // make vel positive, even if scale is negative
          if (vel < 0.0) {
            vel = -vel;
          }
          // use lesser of estimate and previous value
          // use sign of previous value, magnitude of estimate
          if (vel < *(hal_data->vel)) {
            *(hal_data->vel) = vel;
          }
          if (-vel > *(hal_data->vel)) {
            *(hal_data->vel) = -vel;
          }
        } else {
          // its been a long time, stop estimating
          hal_data->counts_since_timeout = 0;
          *(hal_data->vel) = 0;
        }
      } else {
        // we already stopped estimating
        *(hal_data->vel) = 0;
      }
    }

    // compute net counts
    *(hal_data->count) = hal_data->raw_count - hal_data->index_count;

    // scale count to make floating point position
    *(hal_data->pos) = *(hal_data->count) * hal_data->scale;

    // add interpolation value
    delta_time = timebase - hal_data->timestamp;
    interp = *(hal_data->vel) * ((double)delta_time / (double)(device->osc_freq));
    *(hal_data->pos_interp) = *(hal_data->pos) + interp;
  }
}

void mdsio_enc_write(mdsio_mod_t *mod, long period, uint32_t *data) {
  // this module is input only
  memset(data, 0, MDSIO_ENC_LEN);
}

