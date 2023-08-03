// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Thomas Benz <tbenz@iis.ee.ethz.ch>

#ifndef AXIRT_REG32_H_
#define AXIRT_REG32_H_

#include <stdint.h>
#include <stdbool.h>

// a file called params.h needs to be included defining the base of the RT register file using
// the symbol `__base_axirt`.

// functions accessing guard unit
void __axirt_claim(bool read_excl, bool write_excl);

void __axirt_release();

// setter functions
void __axirt_set_len_limit(uint8_t limit, uint8_t mgr_id);

void __axirt_set_len_limit_group(uint8_t limit, uint8_t group_id);

void __axirt_set_region(uint64_t start_addr, uint64_t end_addr, uint8_t region_id, uint8_t mgr_id);

void __axirt_set_period(uint32_t period, uint8_t region_id, uint8_t mgr_id);

void __axirt_set_budget(uint32_t budget, uint8_t region_id, uint8_t mgr_id);

// config functions
void __axirt_enable(uint32_t enable);

void __axirt_disable();

#endif
