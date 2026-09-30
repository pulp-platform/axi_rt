// Generated register defines for axi_tmu

// Copyright information found in source file:
// Copyright 2025 ETH Zurich and University of Bologna.

// Licensing information found in source file:
// Licensed under Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

#ifndef _AXI_TMU_REG_DEFS_
#define _AXI_TMU_REG_DEFS_

#ifdef __cplusplus
extern "C" {
#endif
// Register width
#define AXI_TMU_PARAM_REG_WIDTH 32

// time budget from axvld to axrdy
#define AXI_TMU_BUDGET_AVLD_ARDY_REG_OFFSET 0x0
#define AXI_TMU_BUDGET_AVLD_ARDY_BUDGET_AVLD_ARDY_MASK 0xff
#define AXI_TMU_BUDGET_AVLD_ARDY_BUDGET_AVLD_ARDY_OFFSET 0
#define AXI_TMU_BUDGET_AVLD_ARDY_BUDGET_AVLD_ARDY_FIELD \
  ((bitfield_field32_t) { .mask = AXI_TMU_BUDGET_AVLD_ARDY_BUDGET_AVLD_ARDY_MASK, .index = AXI_TMU_BUDGET_AVLD_ARDY_BUDGET_AVLD_ARDY_OFFSET })

// time budget for liveness check for write txns
#define AXI_TMU_BUDGET_W_LIVENESS_REG_OFFSET 0x4
#define AXI_TMU_BUDGET_W_LIVENESS_BUDGET_W_LIVENESS_MASK 0xff
#define AXI_TMU_BUDGET_W_LIVENESS_BUDGET_W_LIVENESS_OFFSET 0
#define AXI_TMU_BUDGET_W_LIVENESS_BUDGET_W_LIVENESS_FIELD \
  ((bitfield_field32_t) { .mask = AXI_TMU_BUDGET_W_LIVENESS_BUDGET_W_LIVENESS_MASK, .index = AXI_TMU_BUDGET_W_LIVENESS_BUDGET_W_LIVENESS_OFFSET })

// time budget for b for write txns
#define AXI_TMU_BUDGET_B_REG_OFFSET 0x8
#define AXI_TMU_BUDGET_B_BUDGET_B_MASK 0xff
#define AXI_TMU_BUDGET_B_BUDGET_B_OFFSET 0
#define AXI_TMU_BUDGET_B_BUDGET_B_FIELD \
  ((bitfield_field32_t) { .mask = AXI_TMU_BUDGET_B_BUDGET_B_MASK, .index = AXI_TMU_BUDGET_B_BUDGET_B_OFFSET })

// time budget for liveness check for read txns
#define AXI_TMU_BUDGET_R_LIVENESS_REG_OFFSET 0xc
#define AXI_TMU_BUDGET_R_LIVENESS_BUDGET_R_LIVENESS_MASK 0xff
#define AXI_TMU_BUDGET_R_LIVENESS_BUDGET_R_LIVENESS_OFFSET 0
#define AXI_TMU_BUDGET_R_LIVENESS_BUDGET_R_LIVENESS_FIELD \
  ((bitfield_field32_t) { .mask = AXI_TMU_BUDGET_R_LIVENESS_BUDGET_R_LIVENESS_MASK, .index = AXI_TMU_BUDGET_R_LIVENESS_BUDGET_R_LIVENESS_OFFSET })

// Is the sbr requested to be reset?
#define AXI_TMU_RESET_REG_OFFSET 0x10
#define AXI_TMU_RESET_RESET_BIT 0

// fault logs
#define AXI_TMU_FAULT_LOG_REG_OFFSET 0x14
#define AXI_TMU_FAULT_LOG_FAULT_VALID_BIT 0
#define AXI_TMU_FAULT_LOG_FAULT_TYPE_MASK 0x7
#define AXI_TMU_FAULT_LOG_FAULT_TYPE_OFFSET 1
#define AXI_TMU_FAULT_LOG_FAULT_TYPE_FIELD \
  ((bitfield_field32_t) { .mask = AXI_TMU_FAULT_LOG_FAULT_TYPE_MASK, .index = AXI_TMU_FAULT_LOG_FAULT_TYPE_OFFSET })
#define AXI_TMU_FAULT_LOG_FAULT_DIR_BIT 4
#define AXI_TMU_FAULT_LOG_FAULT_PHASE_MASK 0xf
#define AXI_TMU_FAULT_LOG_FAULT_PHASE_OFFSET 5
#define AXI_TMU_FAULT_LOG_FAULT_PHASE_FIELD \
  ((bitfield_field32_t) { .mask = AXI_TMU_FAULT_LOG_FAULT_PHASE_MASK, .index = AXI_TMU_FAULT_LOG_FAULT_PHASE_OFFSET })
#define AXI_TMU_FAULT_LOG_FAULT_ID_MASK 0xffff
#define AXI_TMU_FAULT_LOG_FAULT_ID_OFFSET 9
#define AXI_TMU_FAULT_LOG_FAULT_ID_FIELD \
  ((bitfield_field32_t) { .mask = AXI_TMU_FAULT_LOG_FAULT_ID_MASK, .index = AXI_TMU_FAULT_LOG_FAULT_ID_OFFSET })

#ifdef __cplusplus
}  // extern "C"
#endif
#endif  // _AXI_TMU_REG_DEFS_
// End generated register defines for axi_tmu