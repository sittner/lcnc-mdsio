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
#include <linux/slab.h>

#include "rtapi.h"
#include "rtapi_string.h"

#include "hal.h"

#include "mdsio.h"

#include "mdsio_dac.h"
#include "mdsio_dio.h"
#include "mdsio_enc.h"
#include "mdsio_phpe.h"
#include "mdsio_step.h"
#include "mdsio_wdt.h"

void mdsio_read_all(void *arg, long period);
void mdsio_write_all(void *arg, long period);

void mdsio_read_port(void *arg, long period);
void mdsio_write_port(void *arg, long period);

mdsio_mod_t *mdsio_add_module(mdsio_port_t *port, uint16_t type, uint16_t offset);
void mdsio_remove_modules(mdsio_port_t *port);
void mdsio_remove_module(mdsio_mod_t *module);

int mdsio_init(mdsio_dev_t *device) {
  int comp_id;
  char name[HAL_NAME_LEN + 1];

  device->comp_id = 0;
  device->port_count = 0;
  device->first_port = NULL;
  device->last_port = NULL;

  comp_id = hal_init(device->name);
  if (comp_id < 0) {
    return comp_id;
  }

  device->comp_id = comp_id;

  // export read function
  rtapi_snprintf(name, HAL_NAME_LEN, "%s.read-all", device->name);
  if (hal_export_funct(name, mdsio_read_all, device, 0, 0, device->comp_id) != 0) {
    rtapi_print_msg (RTAPI_MSG_ERR, "%s: ERROR: read-all funct export failed\n", device->name);
    return -EIO;
  }

  // export write function
  rtapi_snprintf(name, HAL_NAME_LEN, "%s.write-all", device->name);
  if (hal_export_funct(name, mdsio_write_all, device, 0, 0, device->comp_id) != 0) {
    rtapi_print_msg (RTAPI_MSG_ERR, "%s: ERROR: write-all funct export failed\n", device->name);
    return -EIO;
  }

  return 0;
}

void mdsio_ready(mdsio_dev_t *device) {
  hal_ready(device->comp_id);
}

void mdsio_exit(mdsio_dev_t *device) {
  hal_exit(device->comp_id);
  device->comp_id = 0;
}

void mdsio_read_all(void *arg, long period) {
  mdsio_dev_t *device = arg;
  mdsio_port_t *port;

  for (port = device->first_port; port != NULL; port = port->next) {
    mdsio_read_port(port, period);
  }
}

void mdsio_write_all(void *arg, long period) {
  mdsio_dev_t *device = arg;
  mdsio_port_t *port;

  for (port = device->first_port; port != NULL; port = port->next) {
    mdsio_write_port(port, period);
  }
}

mdsio_port_t *mdsio_create_port(mdsio_dev_t *device, void *device_data) {

  mdsio_port_t *port;
  int i;
  uint32_t conf_val;
  mdsio_mod_t *module;
  uint16_t mod_type, mod_start, mod_end;
  uint16_t mod_bot, mod_top;
  char name[HAL_NAME_LEN + 1];

  // allocate port data
  port = kzalloc(sizeof(mdsio_port_t), GFP_KERNEL);
  if (port == NULL) {
    rtapi_print_msg(RTAPI_MSG_ERR, "%s: ERROR: Unable to allocate port memory\n", device->name);
    goto fail0;
  }

  // initialize port data
  port->device = device;
  port->device_data = device_data;
  port->index = device->port_count;

  // probe modules
  mod_bot = 0xffff;
  mod_top = 0x0000;
  for (i=0; i<MDSIO_MAX_MODS_PER_PORT; i++) {
    // read configuration word
    conf_val = device->proc_read_conf(port, i);

    // get type and start address
    mod_type = conf_val & 0xffff;
    mod_start = (conf_val >> 16) & 0xffff;

    // type = 0 is EOL marker
    if (mod_type == 0) {
      break;
    }

    // add module
    module = mdsio_add_module(port, mod_type, mod_start);
    if (module == NULL) {
      continue;
    }

    // update bottom & top of used memory area
    mod_end = mod_start + module->data_len;
    if (mod_start < mod_bot) {
      mod_bot = mod_start;
    }
    if (mod_end > mod_top) {
      mod_top = mod_end;
    }
  }

  // calculate offset and length of data range
  if (mod_top > 0 && mod_bot < mod_top) {
    port->data_offset = mod_bot;
    port->data_len = (mod_top - mod_bot);
  }

  // allocate input and output data buffer
  port->input_data = kzalloc(port->data_len, GFP_KERNEL);
  if (port->input_data == NULL) {
    rtapi_print_msg(RTAPI_MSG_ERR, "%s: ERROR: Unable to allocate input memory\n", device->name);
    goto fail1;
  }
  port->output_data = kzalloc(port->data_len, GFP_KERNEL);
  if (port->output_data == NULL) {
    rtapi_print_msg(RTAPI_MSG_ERR, "%s: ERROR: Unable to allocate output memory\n", device->name);
    goto fail2;
  }

  // export read function
  rtapi_snprintf(name, HAL_NAME_LEN, "%s.%d.read", device->name, port->index);
  if (hal_export_funct(name, mdsio_read_port, port, 0, 0, device->comp_id) != 0) {
    rtapi_print_msg (RTAPI_MSG_ERR, "%s: ERROR: read funct export for port %d failed\n", device->name, port->index);
    goto fail2;
  }

  // export write function
  rtapi_snprintf(name, HAL_NAME_LEN, "%s.%d.write", device->name, port->index);
  if (hal_export_funct(name, mdsio_write_port, port, 0, 0, device->comp_id) != 0) {
    rtapi_print_msg (RTAPI_MSG_ERR, "%s: ERROR: write funct export for port %d failed\n", device->name, port->index);
    goto fail2;
  }

  // add to list
  MDSIO_LIST_APPEND(device->first_port, device->last_port, port);
  device->port_count++;

  return port;

fail2:
  kfree(port->input_data);
fail1:
  mdsio_remove_modules(port);
  kfree(port);
fail0:
  return NULL;
}

void mdsio_destroy_port(mdsio_port_t *port) {
  mdsio_dev_t *device = port->device;

  // remove from list
  MDSIO_LIST_REMOVE(device->first_port, device->last_port, port);

  kfree(port->output_data);
  kfree(port->input_data);
  mdsio_remove_modules(port);
  kfree(port);

  device->port_count--;
}

void mdsio_read_port(void *arg, long period) {
  mdsio_port_t *port = arg;
  mdsio_dev_t *device = port->device;
  mdsio_mod_t *module;

  device->proc_read_input(port);
  for (module = port->first_module; module != NULL; module = module->next) {
    module->proc_read(module, period, (uint32_t *)(port->input_data + (module->data_offset - port->data_offset)));
  }
}

void mdsio_write_port(void *arg, long period) {
  mdsio_port_t *port = arg;
  mdsio_dev_t *device = port->device;
  mdsio_mod_t *module;

  for (module = port->first_module; module != NULL; module = module->next) {
    module->proc_write(module, period, (uint32_t *)(port->output_data + (module->data_offset - port->data_offset)));
  }
  device->proc_write_output(port);
}

mdsio_mod_t *mdsio_add_module(mdsio_port_t *port, uint16_t type, uint16_t offset) {
  mdsio_dev_t *device = port->device;

  mdsio_mod_t *module;
  int err;
  
  module = kzalloc(sizeof(mdsio_mod_t), GFP_KERNEL);
  if (module == NULL) {
    rtapi_print_msg(RTAPI_MSG_ERR, "%s: ERROR: Unable to allocate module memory\n", device->name);
    goto fail0;
  }

  // initialize module
  module->port = port;
  module->type = type;
  module->data_offset = offset;

  // initialize module specific parts
  err = 0;
  switch (type) {
    case MDSIO_WDT_TYPE:
      err = mdsio_wdt_init(module);
      break;
    case MDSIO_DIO_TYPE:
      err = mdsio_dio_init(module);
      break;
    case MDSIO_DAC_TYPE:
      err = mdsio_dac_init(module);
      break;
    case MDSIO_ENC_TYPE:
      err = mdsio_enc_init(module);
      break;
    case MDSIO_STEP_TYPE:
      err = mdsio_step_init(module);
      break;
    case MDSIO_PHPE_TYPE:
      err = mdsio_phpe_init(module);
      break;
    default:
      rtapi_print_msg(RTAPI_MSG_ERR, "%s: Unknown module type %d found at offset %d.\n", device->name, type, offset);
  }

  // handle error
  if (err) {
    rtapi_print_msg(RTAPI_MSG_ERR, "%s: Failed to initialize module type %d at offset %d.\n", device->name, type, offset);
    goto fail1;
  }

  // add to list
  MDSIO_LIST_APPEND(port->first_module, port->last_module, module);
  port->module_count++;

  rtapi_print_msg(RTAPI_MSG_INFO, "%s: Initialized module type %d at offset %d.\n", device->name, type, offset);
  return module;

fail1:
  kfree(module);
fail0:
  return NULL;
}

void mdsio_remove_modules(mdsio_port_t *port) {
  mdsio_mod_t *module, *prev;

  module = port->last_module;
  while (module != NULL) {
    prev = module->prev;
    mdsio_remove_module(module);
    module = prev;
  }
}

void mdsio_remove_module(mdsio_mod_t *module) {
  mdsio_port_t *port = module->port;

  MDSIO_LIST_REMOVE(port->first_module, port->last_module, module);

  if (module->proc_cleanup != NULL) {
    module->proc_cleanup(module);
  }

  kfree(module);
  port->module_count--;
}

