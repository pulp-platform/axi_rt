// Copyright 2022 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Thomas Benz <tbenz@iis.ee.ethz.ch>

#include "regs/axi_rt.h"
#include "axirt.h"
#include "util.h"
#include "params.h"

// The register block is now generated with PeakRDL and described by the packed
// `axi_rt_regs_t` struct. Each former multi-register is a plain array of 32-bit
// registers (one per manager / region) rather than a bit-packed word.
#define AXIRT_REGS ((volatile axi_rt_regs_t *)&__base_axirt)

// Counts derived directly from the generated register map.
#define AXIRT_NUM_MGR (sizeof(AXIRT_REGS->rt_enable) / sizeof(uint32_t))
#define AXIRT_NUM_REG (sizeof(AXIRT_REGS->read_budget) / sizeof(uint32_t))
#define AXIRT_NUM_SUB (AXIRT_NUM_REG / AXIRT_NUM_MGR)

// functions accessing guard unit
void __axirt_claim(bool read_excl, bool write_excl) {
    uint8_t flags = 4 | (read_excl << 1) | write_excl;
    *reg8(&__base_axirtgrd, 0) = flags;
}

void __axirt_release() {
    *reg32(&__base_axirtgrd, 0) = 0;
}

void __axirt_set_len_limit_group(uint8_t limit, uint8_t group_id) {
    AXIRT_REGS->len_limit[group_id] = limit;
}

void __axirt_set_region(uint64_t start_addr, uint64_t end_addr, uint8_t region_id, uint8_t mgr_id) {
    uint32_t idx = AXIRT_NUM_SUB * mgr_id + region_id;

    AXIRT_REGS->end_addr_sub_high[idx]   = end_addr >> 32;
    AXIRT_REGS->end_addr_sub_low[idx]    = end_addr & 0xffffffff;
    AXIRT_REGS->start_addr_sub_low[idx]  = start_addr & 0xffffffff;
    AXIRT_REGS->start_addr_sub_high[idx] = start_addr >> 32;
}

void __axirt_set_period(uint32_t period, uint8_t region_id, uint8_t mgr_id) {
    uint32_t idx = AXIRT_NUM_SUB * mgr_id + region_id;

    AXIRT_REGS->write_period[idx] = period;
    AXIRT_REGS->read_period[idx]  = period;
}

void __axirt_set_budget(uint32_t budget, uint8_t region_id, uint8_t mgr_id) {
    uint32_t idx = AXIRT_NUM_SUB * mgr_id + region_id;

    AXIRT_REGS->write_budget[idx] = budget;
    AXIRT_REGS->read_budget[idx]  = budget;
}

// config functions
void __axirt_enable(uint32_t enable) {
    for (uint32_t i = 0; i < AXIRT_NUM_MGR; i++) {
        uint32_t en = (enable >> i) & 0x1;
        AXIRT_REGS->rt_enable[i]   = en;
        AXIRT_REGS->imtu_enable[i] = en;
    }
}

void __axirt_disable() {
    for (uint32_t i = 0; i < AXIRT_NUM_MGR; i++) {
        AXIRT_REGS->imtu_enable[i] = 0;
        AXIRT_REGS->rt_enable[i]   = 0;
    }
}

// check isolation
uint8_t __axirt_poll_isolate(uint8_t mgr_id) {
    // TODO: Add some timeout to not wait forever
    while ((AXIRT_REGS->isolated[mgr_id] & 0x1) != 1)
	;
    return AXIRT_REGS->isolated[mgr_id] & 0x1;
}
