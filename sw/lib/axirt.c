// Copyright 2022 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Thomas Benz <tbenz@iis.ee.ethz.ch>

#include "axirt.h"
#include "util.h"
#include "params.h"

// The register block is generated with PeakRDL and described by the packed
// `axi_rt_regs_t` struct. Each former multi-register is an array of 32-bit
// registers (one per manager / region) rather than a bit-packed word.
//
// Integrating projects may point the driver at their own copy of the register
// block -- e.g. one already embedded in a generated system address map -- by
// defining `AXIRT_REGS` (a pointer to the register block) and `AXIRT_GUARD`
// (the address of the access-guard claim register) before this translation
// unit is compiled, typically from their `params.h`. Registers are accessed
// through the raw-word (`.w`) union member, which is layout-compatible with any
// PeakRDL-generated register block regardless of the concrete struct type name.
#ifndef AXIRT_REGS
#include "regs/axi_rt.h"
#define AXIRT_REGS ((volatile axi_rt_regs_t *)&__base_axirt)
#endif
#ifndef AXIRT_GUARD
#define AXIRT_GUARD (&__base_axirtgrd)
#endif

// Counts derived directly from the register map (each register is one word).
#define AXIRT_NUM_MGR (sizeof(AXIRT_REGS->rt_enable) / sizeof(AXIRT_REGS->rt_enable[0]))
#define AXIRT_NUM_REG (sizeof(AXIRT_REGS->read_budget) / sizeof(AXIRT_REGS->read_budget[0]))
#define AXIRT_NUM_SUB (AXIRT_NUM_REG / AXIRT_NUM_MGR)

// functions accessing guard unit
void __axirt_claim(bool read_excl, bool write_excl) {
    uint8_t flags = 4 | (read_excl << 1) | write_excl;
    *reg8(AXIRT_GUARD, 0) = flags;
}

void __axirt_release() {
    *reg32(AXIRT_GUARD, 0) = 0;
}

void __axirt_set_len_limit_group(uint8_t limit, uint8_t group_id) {
    AXIRT_REGS->len_limit[group_id].w = limit;
}

void __axirt_set_region(uint64_t start_addr, uint64_t end_addr, uint8_t region_id, uint8_t mgr_id) {
    uint32_t idx = AXIRT_NUM_SUB * mgr_id + region_id;

    AXIRT_REGS->end_addr_sub_high[idx].w   = end_addr >> 32;
    AXIRT_REGS->end_addr_sub_low[idx].w    = end_addr & 0xffffffff;
    AXIRT_REGS->start_addr_sub_low[idx].w  = start_addr & 0xffffffff;
    AXIRT_REGS->start_addr_sub_high[idx].w = start_addr >> 32;
}

void __axirt_set_period(uint32_t period, uint8_t region_id, uint8_t mgr_id) {
    uint32_t idx = AXIRT_NUM_SUB * mgr_id + region_id;

    AXIRT_REGS->write_period[idx].w = period;
    AXIRT_REGS->read_period[idx].w  = period;
}

void __axirt_set_budget(uint32_t budget, uint8_t region_id, uint8_t mgr_id) {
    uint32_t idx = AXIRT_NUM_SUB * mgr_id + region_id;

    AXIRT_REGS->write_budget[idx].w = budget;
    AXIRT_REGS->read_budget[idx].w  = budget;
}

// config functions
void __axirt_enable(uint32_t enable) {
    for (uint32_t i = 0; i < AXIRT_NUM_MGR; i++) {
        uint32_t en = (enable >> i) & 0x1;
        AXIRT_REGS->rt_enable[i].w   = en;
        AXIRT_REGS->imtu_enable[i].w = en;
    }
}

void __axirt_disable() {
    for (uint32_t i = 0; i < AXIRT_NUM_MGR; i++) {
        AXIRT_REGS->imtu_enable[i].w = 0;
        AXIRT_REGS->rt_enable[i].w   = 0;
    }
}

// check isolation
uint8_t __axirt_poll_isolate(uint8_t mgr_id) {
    // TODO: Add some timeout to not wait forever
    while ((AXIRT_REGS->isolated[mgr_id].w & 0x1) != 1)
	;
    return AXIRT_REGS->isolated[mgr_id].w & 0x1;
}
