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
#ifndef _MDSIO_H_
#define _MDSIO_H_

#include <linux/ctype.h>

#define MDSIO_MAX_MODS_PER_PORT 16

// list macros
#define MDSIO_LIST_APPEND(first, last, item) \
do {                                         \
  (item)->prev = (last);                     \
  if ((item)->prev != NULL) {                \
    (item)->prev->next = (item);             \
  } else {                                   \
    (first) = (item);                        \
  }                                          \
  (last) = (item);                           \
} while (0);                                 \

#define MDSIO_LIST_REMOVE(first, last, item) \
do {                                         \
  if ((item)->prev != NULL) {                \
    (item)->prev->next = (item)->next;       \
  } else {                                   \
    (first) = (item)->next;                  \
  }                                          \
  if ((item)->next != NULL) {                \
    (item)->next->prev = (item)->prev;       \
  } else {                                   \
    (last) = (item)->prev;                   \
  }                                          \
} while (0);                                 \

struct mdsio_dev;
struct mdsio_port;
struct mdsio_mod;

typedef uint32_t (*mdsio_read_conf_t) (struct mdsio_port *port, int word);
typedef void (*mdsio_rw_data_t) (struct mdsio_port *port);
typedef void (*mdsio_mod_rw_t) (struct mdsio_mod *mod, long period, uint32_t *data);
typedef void (*mdsio_mod_cleanup_t) (struct mdsio_mod *mod);

typedef struct mdsio_dev {
  const char *name;
  uint32_t osc_freq;
  int comp_id;
  mdsio_read_conf_t proc_read_conf;
  mdsio_rw_data_t proc_read_input;
  mdsio_rw_data_t proc_write_output;
  int port_count;
  struct mdsio_port *first_port;
  struct mdsio_port *last_port;
} mdsio_dev_t;

typedef struct mdsio_port {
  struct mdsio_port *prev;
  struct mdsio_port *next;
  struct mdsio_dev *device;
  void *device_data;
  int index;
  uint16_t data_offset;
  uint16_t data_len;
  char *input_data;
  char *output_data;
  int module_count;
  struct mdsio_mod *first_module;
  struct mdsio_mod *last_module;
} mdsio_port_t;

typedef struct mdsio_mod {
  struct mdsio_mod *prev;
  struct mdsio_mod *next;
  struct mdsio_port *port;
  uint16_t type;
  uint16_t data_offset;
  uint16_t data_len;
  int index;
  mdsio_mod_cleanup_t proc_cleanup;
  mdsio_mod_rw_t proc_read;
  mdsio_mod_rw_t proc_write;
  void *hal_data;
} mdsio_mod_t;

int mdsio_init(mdsio_dev_t *device);
void mdsio_ready(mdsio_dev_t *device);
void mdsio_exit(mdsio_dev_t *device);

mdsio_port_t *mdsio_create_port(mdsio_dev_t *device, void *device_data);
void mdsio_destroy_port(mdsio_port_t *port);

#endif

