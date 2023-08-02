// Generated register defines for axi_rt

// Copyright information found in source file:
// Copyright 2022 ETH Zurich and University of Bologna.

// Licensing information found in source file:
// Licensed under Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

#ifndef _AXI_RT_REG_DEFS_
#define _AXI_RT_REG_DEFS_

#ifdef __cplusplus
extern "C" {
#endif
// Maximum number of managers.
#define AXI_RT_PARAM_NUM_MRG 2

// Configured number of subordinate regions.
#define AXI_RT_PARAM_NUM_SUB 2

// Configured number of required registers.
#define AXI_RT_PARAM_NUM_REG 4

// Register width
#define AXI_RT_PARAM_REG_WIDTH 32

// Value of the major_version.
#define AXI_RT_MAJOR_VERSION_REG_OFFSET 0x0

// Value of the minor_version.
#define AXI_RT_MINOR_VERSION_REG_OFFSET 0x4

// Value of the patch_version.
#define AXI_RT_PATCH_VERSION_REG_OFFSET 0x8

// Enable RT feature on master (common parameters)
#define AXI_RT_RT_ENABLE_ENABLE_FIELD_WIDTH 1
#define AXI_RT_RT_ENABLE_ENABLE_FIELDS_PER_REG 32
#define AXI_RT_RT_ENABLE_MULTIREG_COUNT 1

// Enable RT feature on master
#define AXI_RT_RT_ENABLE_REG_OFFSET 0xc
#define AXI_RT_RT_ENABLE_ENABLE_0_BIT 0
#define AXI_RT_RT_ENABLE_ENABLE_1_BIT 1

// Is the RT inactive? (common parameters)
#define AXI_RT_RT_BYPASSED_BYPASSED_FIELD_WIDTH 1
#define AXI_RT_RT_BYPASSED_BYPASSED_FIELDS_PER_REG 32
#define AXI_RT_RT_BYPASSED_MULTIREG_COUNT 1

// Is the RT inactive?
#define AXI_RT_RT_BYPASSED_REG_OFFSET 0x10
#define AXI_RT_RT_BYPASSED_BYPASSED_0_BIT 0
#define AXI_RT_RT_BYPASSED_BYPASSED_1_BIT 1

// Fragmentation of the bursts in beats. (common parameters)
#define AXI_RT_LEN_LIMIT_LEN_FIELD_WIDTH 8
#define AXI_RT_LEN_LIMIT_LEN_FIELDS_PER_REG 4
#define AXI_RT_LEN_LIMIT_MULTIREG_COUNT 1

// Fragmentation of the bursts in beats.
#define AXI_RT_LEN_LIMIT_REG_OFFSET 0x14
#define AXI_RT_LEN_LIMIT_LEN_0_MASK 0xff
#define AXI_RT_LEN_LIMIT_LEN_0_OFFSET 0
#define AXI_RT_LEN_LIMIT_LEN_0_FIELD \
  ((bitfield_field32_t) { .mask = AXI_RT_LEN_LIMIT_LEN_0_MASK, .index = AXI_RT_LEN_LIMIT_LEN_0_OFFSET })
#define AXI_RT_LEN_LIMIT_LEN_1_MASK 0xff
#define AXI_RT_LEN_LIMIT_LEN_1_OFFSET 8
#define AXI_RT_LEN_LIMIT_LEN_1_FIELD \
  ((bitfield_field32_t) { .mask = AXI_RT_LEN_LIMIT_LEN_1_MASK, .index = AXI_RT_LEN_LIMIT_LEN_1_OFFSET })

// Enables the IMTU. (common parameters)
#define AXI_RT_IMTU_ENABLE_ENABLE_FIELD_WIDTH 1
#define AXI_RT_IMTU_ENABLE_ENABLE_FIELDS_PER_REG 32
#define AXI_RT_IMTU_ENABLE_MULTIREG_COUNT 1

// Enables the IMTU.
#define AXI_RT_IMTU_ENABLE_REG_OFFSET 0x18
#define AXI_RT_IMTU_ENABLE_ENABLE_0_BIT 0
#define AXI_RT_IMTU_ENABLE_ENABLE_1_BIT 1

// Resets both the period and the budget. (common parameters)
#define AXI_RT_IMTU_ABORT_ABORT_FIELD_WIDTH 1
#define AXI_RT_IMTU_ABORT_ABORT_FIELDS_PER_REG 32
#define AXI_RT_IMTU_ABORT_MULTIREG_COUNT 1

// Resets both the period and the budget.
#define AXI_RT_IMTU_ABORT_REG_OFFSET 0x1c
#define AXI_RT_IMTU_ABORT_ABORT_0_BIT 0
#define AXI_RT_IMTU_ABORT_ABORT_1_BIT 1

// The lower 32bit of the start address. (common parameters)
#define AXI_RT_START_ADDR_SUB_LOW_WRITE_BUDGET_FIELD_WIDTH 32
#define AXI_RT_START_ADDR_SUB_LOW_WRITE_BUDGET_FIELDS_PER_REG 1
#define AXI_RT_START_ADDR_SUB_LOW_MULTIREG_COUNT 4

// The lower 32bit of the start address.
#define AXI_RT_START_ADDR_SUB_LOW_0_REG_OFFSET 0x20

// The lower 32bit of the start address.
#define AXI_RT_START_ADDR_SUB_LOW_1_REG_OFFSET 0x24

// The lower 32bit of the start address.
#define AXI_RT_START_ADDR_SUB_LOW_2_REG_OFFSET 0x28

// The lower 32bit of the start address.
#define AXI_RT_START_ADDR_SUB_LOW_3_REG_OFFSET 0x2c

// The higher 32bit of the start address. (common parameters)
#define AXI_RT_START_ADDR_SUB_HIGH_WRITE_BUDGET_FIELD_WIDTH 32
#define AXI_RT_START_ADDR_SUB_HIGH_WRITE_BUDGET_FIELDS_PER_REG 1
#define AXI_RT_START_ADDR_SUB_HIGH_MULTIREG_COUNT 4

// The higher 32bit of the start address.
#define AXI_RT_START_ADDR_SUB_HIGH_0_REG_OFFSET 0x30

// The higher 32bit of the start address.
#define AXI_RT_START_ADDR_SUB_HIGH_1_REG_OFFSET 0x34

// The higher 32bit of the start address.
#define AXI_RT_START_ADDR_SUB_HIGH_2_REG_OFFSET 0x38

// The higher 32bit of the start address.
#define AXI_RT_START_ADDR_SUB_HIGH_3_REG_OFFSET 0x3c

// The lower 32bit of the end address. (common parameters)
#define AXI_RT_END_ADDR_SUB_LOW_WRITE_BUDGET_FIELD_WIDTH 32
#define AXI_RT_END_ADDR_SUB_LOW_WRITE_BUDGET_FIELDS_PER_REG 1
#define AXI_RT_END_ADDR_SUB_LOW_MULTIREG_COUNT 4

// The lower 32bit of the end address.
#define AXI_RT_END_ADDR_SUB_LOW_0_REG_OFFSET 0x40

// The lower 32bit of the end address.
#define AXI_RT_END_ADDR_SUB_LOW_1_REG_OFFSET 0x44

// The lower 32bit of the end address.
#define AXI_RT_END_ADDR_SUB_LOW_2_REG_OFFSET 0x48

// The lower 32bit of the end address.
#define AXI_RT_END_ADDR_SUB_LOW_3_REG_OFFSET 0x4c

// The higher 32bit of the end address. (common parameters)
#define AXI_RT_END_ADDR_SUB_HIGH_WRITE_BUDGET_FIELD_WIDTH 32
#define AXI_RT_END_ADDR_SUB_HIGH_WRITE_BUDGET_FIELDS_PER_REG 1
#define AXI_RT_END_ADDR_SUB_HIGH_MULTIREG_COUNT 4

// The higher 32bit of the end address.
#define AXI_RT_END_ADDR_SUB_HIGH_0_REG_OFFSET 0x50

// The higher 32bit of the end address.
#define AXI_RT_END_ADDR_SUB_HIGH_1_REG_OFFSET 0x54

// The higher 32bit of the end address.
#define AXI_RT_END_ADDR_SUB_HIGH_2_REG_OFFSET 0x58

// The higher 32bit of the end address.
#define AXI_RT_END_ADDR_SUB_HIGH_3_REG_OFFSET 0x5c

// The budget for writes. (common parameters)
#define AXI_RT_WRITE_BUDGET_WRITE_BUDGET_FIELD_WIDTH 32
#define AXI_RT_WRITE_BUDGET_WRITE_BUDGET_FIELDS_PER_REG 1
#define AXI_RT_WRITE_BUDGET_MULTIREG_COUNT 4

// The budget for writes.
#define AXI_RT_WRITE_BUDGET_0_REG_OFFSET 0x60

// The budget for writes.
#define AXI_RT_WRITE_BUDGET_1_REG_OFFSET 0x64

// The budget for writes.
#define AXI_RT_WRITE_BUDGET_2_REG_OFFSET 0x68

// The budget for writes.
#define AXI_RT_WRITE_BUDGET_3_REG_OFFSET 0x6c

// The budget for reads. (common parameters)
#define AXI_RT_READ_BUDGET_READ_BUDGET_FIELD_WIDTH 32
#define AXI_RT_READ_BUDGET_READ_BUDGET_FIELDS_PER_REG 1
#define AXI_RT_READ_BUDGET_MULTIREG_COUNT 4

// The budget for reads.
#define AXI_RT_READ_BUDGET_0_REG_OFFSET 0x70

// The budget for reads.
#define AXI_RT_READ_BUDGET_1_REG_OFFSET 0x74

// The budget for reads.
#define AXI_RT_READ_BUDGET_2_REG_OFFSET 0x78

// The budget for reads.
#define AXI_RT_READ_BUDGET_3_REG_OFFSET 0x7c

// The period for writes. (common parameters)
#define AXI_RT_WRITE_PERIOD_WRITE_PERIOD_FIELD_WIDTH 32
#define AXI_RT_WRITE_PERIOD_WRITE_PERIOD_FIELDS_PER_REG 1
#define AXI_RT_WRITE_PERIOD_MULTIREG_COUNT 4

// The period for writes.
#define AXI_RT_WRITE_PERIOD_0_REG_OFFSET 0x80

// The period for writes.
#define AXI_RT_WRITE_PERIOD_1_REG_OFFSET 0x84

// The period for writes.
#define AXI_RT_WRITE_PERIOD_2_REG_OFFSET 0x88

// The period for writes.
#define AXI_RT_WRITE_PERIOD_3_REG_OFFSET 0x8c

// The period for reads. (common parameters)
#define AXI_RT_READ_PERIOD_READ_PERIOD_FIELD_WIDTH 32
#define AXI_RT_READ_PERIOD_READ_PERIOD_FIELDS_PER_REG 1
#define AXI_RT_READ_PERIOD_MULTIREG_COUNT 4

// The period for reads.
#define AXI_RT_READ_PERIOD_0_REG_OFFSET 0x90

// The period for reads.
#define AXI_RT_READ_PERIOD_1_REG_OFFSET 0x94

// The period for reads.
#define AXI_RT_READ_PERIOD_2_REG_OFFSET 0x98

// The period for reads.
#define AXI_RT_READ_PERIOD_3_REG_OFFSET 0x9c

// The budget left for writes. (common parameters)
#define AXI_RT_WRITE_BUDGET_LEFT_WRITE_BUDGET_LEFT_FIELD_WIDTH 32
#define AXI_RT_WRITE_BUDGET_LEFT_WRITE_BUDGET_LEFT_FIELDS_PER_REG 1
#define AXI_RT_WRITE_BUDGET_LEFT_MULTIREG_COUNT 4

// The budget left for writes.
#define AXI_RT_WRITE_BUDGET_LEFT_0_REG_OFFSET 0xa0

// The budget left for writes.
#define AXI_RT_WRITE_BUDGET_LEFT_1_REG_OFFSET 0xa4

// The budget left for writes.
#define AXI_RT_WRITE_BUDGET_LEFT_2_REG_OFFSET 0xa8

// The budget left for writes.
#define AXI_RT_WRITE_BUDGET_LEFT_3_REG_OFFSET 0xac

// The budget left for reads. (common parameters)
#define AXI_RT_READ_BUDGET_LEFT_READ_BUDGET_LEFT_FIELD_WIDTH 32
#define AXI_RT_READ_BUDGET_LEFT_READ_BUDGET_LEFT_FIELDS_PER_REG 1
#define AXI_RT_READ_BUDGET_LEFT_MULTIREG_COUNT 4

// The budget left for reads.
#define AXI_RT_READ_BUDGET_LEFT_0_REG_OFFSET 0xb0

// The budget left for reads.
#define AXI_RT_READ_BUDGET_LEFT_1_REG_OFFSET 0xb4

// The budget left for reads.
#define AXI_RT_READ_BUDGET_LEFT_2_REG_OFFSET 0xb8

// The budget left for reads.
#define AXI_RT_READ_BUDGET_LEFT_3_REG_OFFSET 0xbc

// The period left for writes. (common parameters)
#define AXI_RT_WRITE_PERIOD_LEFT_WRITE_PERIOD_LEFT_FIELD_WIDTH 32
#define AXI_RT_WRITE_PERIOD_LEFT_WRITE_PERIOD_LEFT_FIELDS_PER_REG 1
#define AXI_RT_WRITE_PERIOD_LEFT_MULTIREG_COUNT 4

// The period left for writes.
#define AXI_RT_WRITE_PERIOD_LEFT_0_REG_OFFSET 0xc0

// The period left for writes.
#define AXI_RT_WRITE_PERIOD_LEFT_1_REG_OFFSET 0xc4

// The period left for writes.
#define AXI_RT_WRITE_PERIOD_LEFT_2_REG_OFFSET 0xc8

// The period left for writes.
#define AXI_RT_WRITE_PERIOD_LEFT_3_REG_OFFSET 0xcc

// The period left for reads. (common parameters)
#define AXI_RT_READ_PERIOD_LEFT_READ_PERIOD_LEFT_FIELD_WIDTH 32
#define AXI_RT_READ_PERIOD_LEFT_READ_PERIOD_LEFT_FIELDS_PER_REG 1
#define AXI_RT_READ_PERIOD_LEFT_MULTIREG_COUNT 4

// The period left for reads.
#define AXI_RT_READ_PERIOD_LEFT_0_REG_OFFSET 0xd0

// The period left for reads.
#define AXI_RT_READ_PERIOD_LEFT_1_REG_OFFSET 0xd4

// The period left for reads.
#define AXI_RT_READ_PERIOD_LEFT_2_REG_OFFSET 0xd8

// The period left for reads.
#define AXI_RT_READ_PERIOD_LEFT_3_REG_OFFSET 0xdc

// Is the interface requested to be isolated? (common parameters)
#define AXI_RT_ISOLATE_ISOLATE_FIELD_WIDTH 1
#define AXI_RT_ISOLATE_ISOLATE_FIELDS_PER_REG 32
#define AXI_RT_ISOLATE_MULTIREG_COUNT 1

// Is the interface requested to be isolated?
#define AXI_RT_ISOLATE_REG_OFFSET 0xe0
#define AXI_RT_ISOLATE_ISOLATE_0_BIT 0
#define AXI_RT_ISOLATE_ISOLATE_1_BIT 1

// Is the interface isolated? (common parameters)
#define AXI_RT_ISOLATED_ISOLATED_FIELD_WIDTH 1
#define AXI_RT_ISOLATED_ISOLATED_FIELDS_PER_REG 32
#define AXI_RT_ISOLATED_MULTIREG_COUNT 1

// Is the interface isolated?
#define AXI_RT_ISOLATED_REG_OFFSET 0xe4
#define AXI_RT_ISOLATED_ISOLATED_0_BIT 0
#define AXI_RT_ISOLATED_ISOLATED_1_BIT 1

// Value of the num_managers parameter.
#define AXI_RT_NUM_MANAGERS_REG_OFFSET 0xe8

// Value of the addr_width parameter.
#define AXI_RT_ADDR_WIDTH_REG_OFFSET 0xec

// Value of the data_width parameter.
#define AXI_RT_DATA_WIDTH_REG_OFFSET 0xf0

// Value of the id_width parameter.
#define AXI_RT_ID_WIDTH_REG_OFFSET 0xf4

// Value of the user_width parameter.
#define AXI_RT_USER_WIDTH_REG_OFFSET 0xf8

// Value of the num_pending parameter.
#define AXI_RT_NUM_PENDING_REG_OFFSET 0xfc

// Value of the w_buffer_depth parameter.
#define AXI_RT_W_BUFFER_DEPTH_REG_OFFSET 0x100

// Value of the num_addr_regions parameter.
#define AXI_RT_NUM_ADDR_REGIONS_REG_OFFSET 0x104

// Value of the period_width parameter.
#define AXI_RT_PERIOD_WIDTH_REG_OFFSET 0x108

// Value of the budget_width parameter.
#define AXI_RT_BUDGET_WIDTH_REG_OFFSET 0x10c

// Value of the max_num_managers parameter.
#define AXI_RT_MAX_NUM_MANAGERS_REG_OFFSET 0x110

#ifdef __cplusplus
}  // extern "C"
#endif
#endif  // _AXI_RT_REG_DEFS_
// End generated register defines for axi_rt