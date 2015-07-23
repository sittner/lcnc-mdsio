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
#include <float.h>

#include "rtapi.h"
#include "rtapi_string.h"
#include "rtapi_math.h"

#include "hal.h"

#include "mdsio.h"
#include "mdsio_step.h"

#define PICKOFF 32
#define ACCEL_DIV (1LL << 16)

static int mdsio_step_index = 0;

typedef struct {
  long long accum;		// frequency generator accumulator
  hal_bit_t *enable;		// pin for enable stepgen
  double old_pos_cmd;		// previous position command (counts)
  hal_s32_t *count;		// pin: captured feedback in counts
  hal_float_t pos_scale;	// param: steps per position unit
  double old_scale;		// stored scale value
  double scale_recip;		// reciprocal value used for scaling
  hal_bit_t pos_mode;		// param: 1 = position mode, 0 = velocity mode
  hal_float_t *vel_cmd;		// pin: velocity command (pos units/sec)
  hal_float_t *pos_cmd;		// pin: position command (position units)
  hal_float_t *pos_fb;		// pin: position feedback (position units)
  hal_float_t freq;		// param: frequency command
  hal_float_t maxvel;		// param: max velocity, (pos units/sec)
  hal_float_t maxaccel;		// param: max accel (pos units/sec^2)
  int printed_error;		// flag to avoid repeated printing
} mdsio_step_channel_data_t;

typedef struct {
  long periodns;		// makepulses function period in nanosec
  double periodfp;		// makepulses function period in seconds
  double freqscale;		// conv. factor from Hz to addval counts
  double accelscale;		// conv. Hz/sec to addval cnts/period
  long old_dtns;		// update_freq funct period in nsec
  double dt;			// update_freq period in seconds
  double recip_dt;		// recprocal of period, avoids divides
  double max_ac_lim;		// maximum accel limit
  hal_u32_t step_len;		// parameter: step pulse length
  hal_u32_t step_space;		// parameter: min step pulse spacing
  hal_u32_t dir_hold;		// param: direction hold time
  hal_u32_t dir_setup;		// param: direction setup time
  hal_u32_t old_step_len;	// used to detect parameter changes
  hal_u32_t old_step_space;
  hal_u32_t old_dir_hold;
  hal_u32_t old_dir_setup;
  unsigned long step_len_cnt;
  unsigned long dir_hold_cnt;
  unsigned long dir_setup_cnt;
  mdsio_step_channel_data_t channels[MDSIO_STEP_CHANNELS];
} mdsio_step_data_t;

int mdsio_step_export_pins(mdsio_mod_t *module);
void mdsio_step_read(mdsio_mod_t *mod, long period, uint32_t *data);
void mdsio_step_write(mdsio_mod_t *mod, long period, uint32_t *data);

// helper function - computes integeral multiple of increment that is greater or equal to value
unsigned long ulceil(unsigned long value, unsigned long increment) {
  if (value == 0) {
    return 0;
  }
  return increment * (((value - 1) / increment) + 1);
}

int mdsio_step_init(mdsio_mod_t *module) {
  mdsio_port_t *port= module->port;
  mdsio_dev_t *device= port->device;
  mdsio_step_data_t *hal_data;

  // initialize module
  module->index = mdsio_step_index;
  module->data_len = MDSIO_STEP_LEN;
  module->proc_read = mdsio_step_read;
  module->proc_write = mdsio_step_write;
  mdsio_step_index++;

  if ((hal_data = hal_malloc(sizeof(mdsio_step_data_t))) == 0) {
    rtapi_print_msg(RTAPI_MSG_ERR, "%s.%d.step.%d: ERROR: hal_malloc() failed\n", device->name, port->index, module->index);
    return -EIO;
  }
  memset(hal_data, 0, sizeof(mdsio_step_data_t));
  module->hal_data = hal_data;

  // calculate time constants
  hal_data->periodns = 1000000000L / device->osc_freq;
  hal_data->periodfp = 1.0 / (double)device->osc_freq;
  hal_data->freqscale = (1LL << PICKOFF) * hal_data->periodfp;
  hal_data->accelscale = hal_data->freqscale * hal_data->periodfp * ACCEL_DIV;
  hal_data->max_ac_lim = (ACCEL_DIV - 1) / hal_data->accelscale;
  hal_data->old_dtns = 1000000L;
  hal_data->dt = hal_data->old_dtns * 0.000000001;
  hal_data->recip_dt = 1.0 / hal_data->dt;

  // register pins
  if (mdsio_step_export_pins(module) != 0) {
    rtapi_print_msg(RTAPI_MSG_ERR, "%s.%d.step.%d: ERROR: export_pins() failed\n", device->name, port->index, module->index);
    return -EIO;
  }

  return 0;
}

int mdsio_step_export_pins(mdsio_mod_t *module) {
  mdsio_port_t *port= module->port;
  mdsio_dev_t *device= port->device;
  mdsio_step_data_t *module_data = module->hal_data;
  mdsio_step_channel_data_t *data;
  const char *dname = device->name;
  int comp_id = device->comp_id;
  int pidx = port->index;
  int midx = module->index;
  int err;
  int i;

  // every step type uses steplen
  if ((err = hal_param_u32_newf(HAL_RW, &(module_data->step_len), comp_id, "%s.%d.step.%d.steplen", dname, pidx, midx)) != 0) {
    return err;
  }
  // step/dir and up/down use 'stepspace'
  if ((err = hal_param_u32_newf(HAL_RW, &(module_data->step_space), comp_id, "%s.%d.step.%d.stepspace", dname, pidx, midx)) != 0) {
    return err;
  }
  // step/dir is the only one that uses dirsetup and dirhold
  if ((err = hal_param_u32_newf(HAL_RW, &(module_data->dir_setup), comp_id, "%s.%d.step.%d.dirsetup", dname, pidx, midx)) != 0) {
    return err;
  }
  if ((err = hal_param_u32_newf(HAL_RW, &(module_data->dir_hold), comp_id, "%s.%d.step.%d.dirhold", dname, pidx, midx)) != 0) {
    return err;
  }

  // timing parameter defaults depend on step type
  module_data->step_len = 1;
  module_data->step_space = 1;
  module_data->dir_hold = 1;
  module_data->dir_setup = 1;

  // set 'old' values to make update_freq validate the timing params
  module_data->old_step_len = ~0;
  module_data->old_step_space = ~0;
  module_data->old_dir_hold = ~0;
  module_data->old_dir_setup = ~0;

  for(i=0; i<MDSIO_STEP_CHANNELS; i++) {
    data = &(module_data->channels[i]);

    // export pin for counts
    if ((err = hal_pin_s32_newf(HAL_OUT, &(data->count), comp_id, "%s.%d.step.%d.ch%d-counts", dname, pidx, midx, i)) != 0) {
      return err;
    }
    // export parameter for position scaling
    if ((err = hal_param_float_newf(HAL_RW, &(data->pos_scale), comp_id, "%s.%d.step.%d.ch%d-pos-scale", dname, pidx, midx, i)) != 0) {
      return err;
    }
    // export pin for mode
    if ((err = hal_param_bit_newf(HAL_RW, &(data->pos_mode), comp_id, "%s.%d.step.%d.ch%d-pos-mode", dname, pidx, midx, i)) != 0) {
      return err;
    }
    // export pin for command
    if ((err = hal_pin_float_newf(HAL_IN, &(data->pos_cmd), comp_id, "%s.%d.step.%d.ch%d-pos-cmd", dname, pidx, midx, i)) != 0) {
      return err;
    }
    if ((err = hal_pin_float_newf(HAL_IN, &(data->vel_cmd), comp_id, "%s.%d.step.%d.ch%d-velo-cmd", dname, pidx, midx, i)) != 0) {
      return err;
    }
    // export pin for enable command
    if ((err = hal_pin_bit_newf(HAL_IN, &(data->enable), comp_id, "%s.%d.step.%d.ch%d-enable", dname, pidx, midx, i)) != 0) {
      return err;
    }
    // export pin for scaled position
    if ((err = hal_pin_float_newf(HAL_OUT, &(data->pos_fb), comp_id, "%s.%d.step.%d.ch%d-pos-fb", dname, pidx, midx, i)) != 0) {
      return err;
    }
    // export param for scaled velocity (frequency in Hz)
    if ((err = hal_param_float_newf(HAL_RO, &(data->freq), comp_id, "%s.%d.step.%d.ch%d-freq", dname, pidx, midx, i)) != 0) {
      return err;
    }
    // export parameter for max frequency
    if ((err = hal_param_float_newf(HAL_RW, &(data->maxvel), comp_id, "%s.%d.step.%d.ch%d-maxvel", dname, pidx, midx, i)) != 0) {
      return err;
    }
    // export parameter for max accel/decel
    if ((err = hal_param_float_newf(HAL_RW, &(data->maxaccel), comp_id, "%s.%d.step.%d.ch%d-maxaccel", dname, pidx, midx, i)) != 0) {
      return err;
    }

    // set default parameter values
    data->pos_scale = 1.0;
    data->old_scale = 0.0;
    data->scale_recip = 0.0;
    data->freq = 0.0;
    data->maxvel = 0.0;
    data->maxaccel = 0.0;
    data->pos_mode = 0;

    // accumulator gets a half step offset, so it will step half
    // way between integer positions, not at the integer positions
    data->accum = 1 << (PICKOFF - 1);
    *(data->enable) = 0;

    // other init
    data->printed_error = 0;
    data->old_pos_cmd = 0.0;

    // set initial pin values
    *(data->count) = 0;
    *(data->pos_fb) = 0.0;
    *(data->pos_cmd) = 0.0;
    *(data->vel_cmd) = 0.0;
  }

  return 0;
}

void mdsio_step_read(mdsio_mod_t *mod, long period, uint32_t *data) {
  mdsio_step_data_t *module_data = mod->hal_data;
  mdsio_step_channel_data_t *hal_data;
  int i, word;
  long long int accum_h, accum_l;

  for (i=0, word=3; i<MDSIO_STEP_CHANNELS; i++, word+=4) {
    hal_data = &(module_data->channels[i]);

    // read accu
    accum_h = data[word + 2];
    accum_l = data[word + 3];
    hal_data->accum = (accum_h << 32) + accum_l;

    // compute integer counts
    *(hal_data->count) = hal_data->accum >> PICKOFF;

    // check for change in scale value
    if (hal_data->pos_scale != hal_data->old_scale) {
        // validate the new scale value
        if ((hal_data->pos_scale < 1e-20) && (hal_data->pos_scale > -1e-20)) {
          // value too small, divide by zero is a bad thing
          hal_data->pos_scale = 1.0;
        }
        // get ready to detect future scale changes
        hal_data->old_scale = hal_data->pos_scale;
        // we will need the reciprocal, and the accum is fixed point with
        // fractional bits, so we precalc some stuff
        hal_data->scale_recip = (1.0 / (1LL << PICKOFF)) / hal_data->pos_scale;
    }

    // scale accumulator to make floating point position, after
    // removing the one-half count offset
    *(hal_data->pos_fb) = (double) (hal_data->accum - (1 << (PICKOFF - 1))) * hal_data->scale_recip;
  }
}

void mdsio_step_write(mdsio_mod_t *mod, long period, uint32_t *data) {
  mdsio_step_data_t *module_data = mod->hal_data;
  mdsio_port_t *port= mod->port;
  mdsio_dev_t *device= port->device;
  mdsio_step_channel_data_t *hal_data;
  int i, word;
  long min_step_period;
  double pos_cmd, vel_cmd, curr_pos, curr_vel, avg_v, max_freq, max_ac;
  double match_ac, match_time, est_out, est_cmd, est_err, dp, dv, new_vel;
  double desired_freq;

  memset(data, 0, MDSIO_STEP_LEN);

  // process timing parameters
  if (module_data->step_len != module_data->old_step_len) {
    // must be non-zero
    if (module_data->step_len == 0) {
      module_data->step_len = 1;
    }
    // make integer multiple of periodns
    module_data->old_step_len = ulceil(module_data->step_len, module_data->periodns);
    module_data->step_len = module_data->old_step_len;
    module_data->step_len_cnt = module_data->step_len / module_data->periodns;
  }

  if (module_data->step_space != module_data->old_step_space) {
    // make integer multiple of periodns
    module_data->old_step_space = ulceil(module_data->step_space, module_data->periodns);
    module_data->step_space = module_data->old_step_space;
  }

  if (module_data->dir_setup != module_data->old_dir_setup) {
    // make integer multiple of periodns
    module_data->old_dir_setup = ulceil(module_data->dir_setup, module_data->periodns);
    module_data->dir_setup = module_data->old_dir_setup;
    module_data->dir_setup_cnt = module_data->dir_setup / module_data->periodns;
  }

  if (module_data->dir_hold != module_data->old_dir_hold) {
    if ((module_data->dir_hold + module_data->dir_setup) == 0) {
      // dirdelay must be non-zero
      module_data->dir_hold = 1;
    }
    module_data->old_dir_hold = ulceil(module_data->dir_hold, module_data->periodns);
    module_data->dir_hold = module_data->old_dir_hold;
    module_data->dir_hold_cnt = module_data->dir_hold / module_data->periodns;
  }

  // recalc constants related to the period of this funct
  // only recalc constants if period changes
  if (period != module_data->old_dtns) {
    // get ready to detect future period changes
    module_data->old_dtns = period;
    // dT is the period of this thread, used for the position loop
    module_data->dt = period * 0.000000001;
    // calc the reciprocal once here, to avoid multiple divides later
    module_data->recip_dt = 1.0 / module_data->dt;
  }

  data[0] = module_data->step_len_cnt;
  data[1] = module_data->dir_hold_cnt;
  data[2] = module_data->dir_setup_cnt;

  for (i=0, word=3; i<MDSIO_STEP_CHANNELS; i++, word+=4) {
    hal_data = &(module_data->channels[i]);

    // check for scale change
    if (hal_data->pos_scale != hal_data->old_scale) {
      // validate the new scale value
      if ((hal_data->pos_scale < 1e-20) && (hal_data->pos_scale > -1e-20)) {
        // value too small, divide by zero is a bad thing
        hal_data->pos_scale = 1.0;
      }
      // get ready to detect future scale changes
      hal_data->old_scale = hal_data->pos_scale;
      // we will need the reciprocal, and the accum is fixed point with
      // fractional bits, so we precalc some stuff
      hal_data->scale_recip = (1.0 / (1LL << PICKOFF)) / hal_data->pos_scale;
    }

    // calculate frequency limit
    min_step_period = module_data->step_len + module_data->step_space;
    max_freq = 1.0 / (min_step_period * 0.000000001);

    // check for user specified frequency limit parameter
    if (hal_data->maxvel <= 0.0) {
      // set to zero if negative
      hal_data->maxvel = 0.0;
    } else {
      // parameter is non-zero, compare to max_freq
      desired_freq = hal_data->maxvel * fabs(hal_data->pos_scale);
      if (desired_freq > max_freq) {
        // parameter is too high, complain about it
        if (!hal_data->printed_error) {
          rtapi_print_msg(RTAPI_MSG_ERR, "%s.step.%d: The requested maximum velocity of %d steps/sec is too high.\n", device->name, port->index, (int)desired_freq);
          rtapi_print_msg(RTAPI_MSG_ERR, "%s.step.%d: The maximum possible frequency is %d steps/second\n", device->name, port->index, (int)max_freq);
          hal_data->printed_error = 1;
        }
        // parameter is too high, limit it
        hal_data->maxvel = max_freq / fabs(hal_data->pos_scale);
      } else {
        // lower max_freq to match parameter
        max_freq = hal_data->maxvel * fabs(hal_data->pos_scale);
      }
    }

    // set internal accel limit to its absolute max, which is
    // zero to full speed in one thread period
    max_ac = max_freq * module_data->recip_dt;

    // check hardware limit
    if (max_ac > module_data->max_ac_lim) max_ac = module_data->max_ac_lim;

    // check for user specified accel limit parameter
    if (hal_data->maxaccel <= 0.0) {
      // set to zero if negative
      hal_data->maxaccel = 0.0;
    } else {
      // parameter is non-zero, compare to max_ac
      if ((hal_data->maxaccel * fabs(hal_data->pos_scale)) > max_ac) {
        // parameter is too high, lower it
        hal_data->maxaccel = max_ac / fabs(hal_data->pos_scale);
      } else {
        // lower limit to match parameter
        max_ac = hal_data->maxaccel * fabs(hal_data->pos_scale);
      }
    }

    // calculate new deltalim
    data[word + 1] = max_ac * module_data->accelscale;

    // test for disabled stepgen
    if (*hal_data->enable == 0) {
      // disabled: keep updating old_pos_cmd (if in pos ctrl mode)
      if (hal_data->pos_mode) {
        hal_data->old_pos_cmd = *hal_data->pos_cmd * hal_data->pos_scale;
      }
      // set velocity to zero
      hal_data->freq = 0;
      // and skip to next one
      continue;
    }

    // at this point, all scaling, limits, and other parameter
    // changes have been handled - time for the main control
    if (hal_data->pos_mode) {
      // calculate position command in counts
      pos_cmd = *hal_data->pos_cmd * hal_data->pos_scale;

      // calculate velocity command in counts/sec
      vel_cmd = (pos_cmd - hal_data->old_pos_cmd) * module_data->recip_dt;
      hal_data->old_pos_cmd = pos_cmd;

      // convert from fixed point to double, after subtracting
      // the one-half step offset
      curr_pos = (hal_data->accum - (1LL << (PICKOFF - 1))) * (1.0 / (1LL << PICKOFF));
      // get velocity in counts/sec
      curr_vel = hal_data->freq;

      // At this point we have good values for pos_cmd, curr_pos,
      // vel_cmd, curr_vel, max_freq and max_ac, all in counts,
      // counts/sec, or counts/sec^2.  Now we just have to do
      // something useful with them.
      // determine which way we need to ramp to match velocity
      if (vel_cmd > curr_vel) {
        match_ac = max_ac;
      } else {
        match_ac = -max_ac;
      }

      // determine how long the match would take
      match_time = (vel_cmd - curr_vel) / match_ac;

      // calc output position at the end of the match
      avg_v = (vel_cmd + curr_vel) * 0.5;
      est_out = curr_pos + avg_v * match_time;

      // calculate the expected command position at that time
      est_cmd = pos_cmd + vel_cmd * (match_time - 1.5 * module_data->dt);

      // calculate error at that time
      est_err = est_out - est_cmd;
      if (match_time < module_data->dt) {
        // we can match velocity in one period
        if (fabs(est_err) < 0.0001) {
          // after match the position error will be acceptable
          // so we just do the velocity match
          new_vel = vel_cmd;
        } else {
          // try to correct position error
          new_vel = vel_cmd - 0.5 * est_err * module_data->recip_dt;
          // apply accel limits
          if (new_vel > (curr_vel + max_ac * module_data->dt)) {
            new_vel = curr_vel + max_ac * module_data->dt;
          } else if (new_vel < (curr_vel - max_ac * module_data->dt)) {
            new_vel = curr_vel - max_ac * module_data->dt;
          }
        }
      } else {
        // calculate change in final position if we ramp in the
        // opposite direction for one period
        dv = -2.0 * match_ac * module_data->dt;
        dp = dv * match_time;

        // decide which way to ramp
        if (fabs(est_err + dp * 2.0) < fabs(est_err)) {
          match_ac = -match_ac;
        }

        // and do it
        new_vel = curr_vel + match_ac * module_data->dt;
      }

      // apply frequency limit
      if (new_vel > max_freq) {
        new_vel = max_freq;
      } else if (new_vel < -max_freq) {
        new_vel = -max_freq;
      }
      // end of position mode
    } else {
      // velocity mode is simpler
      // calculate velocity command in counts/sec
      vel_cmd = *(hal_data->vel_cmd) * hal_data->pos_scale;

      // apply frequency limit
      if (vel_cmd > max_freq) {
        vel_cmd = max_freq;
      } else if (vel_cmd < -max_freq) {
        vel_cmd = -max_freq;
      }

      // calc max change in frequency in one period
      dv = max_ac * module_data->dt;

      // apply accel limit
      if (vel_cmd > (hal_data->freq + dv)) {
        new_vel = hal_data->freq + dv;
      } else if (vel_cmd < (hal_data->freq - dv)) {
        new_vel = hal_data->freq - dv;
      } else {
        new_vel = vel_cmd;
      }
      // end of velocity mode
    }
    hal_data->freq = new_vel;

    // calculate new addval
    data[word + 0] = hal_data->freq * module_data->freqscale;
  }
}

