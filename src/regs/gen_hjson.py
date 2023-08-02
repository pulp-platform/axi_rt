# Copyright 2022 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
# Licensed under Solderpad Hardware License, Version 0.51, see LICENSE for details.
#
# Authors:
# - Thomas Benz <tbenz@iis.ee.ethz.ch>

import sys

REG_STR = '''
// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
// Licensed under Solderpad Hardware License, Version 0.51, see LICENSE for details.
//
// Automatically generated by {script_name}
//
// Authors:
// - Thomas Benz <tbenz@iis.ee.ethz.ch>


{{
  name: "axi_rt"
  clock_primary: "clk_i"
  bus_interfaces: [
    {{ protocol: "reg_iface", direction: "device" }}
  ],
  regwidth: 32

  param_list: [
    {{ name: "NumMrg",
      desc: "Maximum number of managers.",
      type: "int",
      default: "{num_managers}"
    }},
    {{ name: "NumSub",
      desc: "Configured number of subordinate regions.",
      type: "int",
      default: "{num_subordinates}"
    }}
    {{ name: "NumReg",
      desc: "Configured number of required registers.",
      type: "int",
      default: "{num_regsters}"
    }}
  ],

  registers: [

    {{ name:     "major_version"
      desc:     "Value of the major_version."
      swaccess: "ro"
      resval:   "{major}"
      fields: [
        {{ bits: "31:0", name: "major_version", desc: "Value of the major_version." }}
      ]
    }}

    {{ name:     "minor_version"
      desc:     "Value of the minor_version."
      swaccess: "ro"
      resval:   "{minor}"
      fields: [
        {{ bits: "31:0", name: "minor_version", desc: "Value of the minor_version." }}
      ]
    }}

    {{ name:     "patch_version"
      desc:     "Value of the patch_version."
      swaccess: "ro"
      resval:   "{patch}"
      fields: [
        {{ bits: "31:0", name: "patch_version", desc: "Value of the patch_version." }}
      ]
    }}

    {{ multireg:
      {{ name:     "rt_enable"
        desc:     "Enable RT feature on master"
        swaccess: "wo"
        hwaccess: "hro"
        count:    "NumMrg"
        cname:    "rt_enable"
        resval:   "0"
        fields: [
          {{ bits: "0:0", name: "enable", desc: "Enable RT feature on master" }}
        ]
      }}
    }}

    {{ multireg:
      {{ name:     "rt_bypassed"
        desc:     "Is the RT inactive?"
        swaccess: "ro"
        hwaccess: "hwo"
        hwqe:     "true"
        hwext:    "true"
        count:    "NumMrg"
        cname:    "rt_bypassed"
        fields: [
          {{ bits: "0:0", name: "bypassed", desc: "Is the RT inactive?" }}
        ]
      }}
    }}

    {{ multireg:
      {{ name:     "len_limit"
        desc:     "Fragmentation of the bursts in beats."
        swaccess: "wo"
        hwaccess: "hro"
        count:    "NumMrg"
        cname:    "len_limit"
        resval:   "0"
        fields: [
          {{ bits: "7:0", name: "len", desc: "Fragmentation of the bursts in beats." }}
        ]
      }}
    }}

    {{ multireg:
      {{ name:     "imtu_enable"
        desc:     "Enables the IMTU."
        swaccess: "wo"
        hwaccess: "hro"
        count:    "NumMrg"
        cname:    "imtu_enable"
        resval:   "0"
        fields: [
          {{ bits: "0:0", name: "enable", desc: "Enables the IMTU." }}
        ]
      }}
    }}

    {{ multireg:
      {{ name:     "imtu_abort"
        desc:     "Resets both the period and the budget."
        swaccess: "wo"
        hwaccess: "hro"
        count:    "NumMrg"
        cname:    "imtu_abort"
        resval:   "0"
        fields: [
          {{ bits: "0:0", name: "abort", desc: "Resets both the period and the budget." }}
        ]
      }}
    }}
{per_mgr_regs}
    {{ multireg:
      {{ name:     "isolate"
        desc:     "Is the interface requested to be isolated?"
        swaccess: "ro"
        hwaccess: "hwo"
        hwqe:     "true"
        hwext:    "true"
        count:    "NumMrg"
        cname:    "isolate"
        fields: [
          {{ bits: "0:0", name: "isolate", desc: "Is the interface requested to be isolated?" }}
        ]
      }}
    }}

    {{ multireg:
      {{ name:     "isolated"
        desc:     "Is the interface isolated?"
        swaccess: "ro"
        hwaccess: "hwo"
        hwqe:     "true"
        hwext:    "true"
        count:    "NumMrg"
        cname:    "isolated"
        fields: [
          {{ bits: "0:0", name: "isolated", desc: "Is the interface isolated?" }}
        ]
      }}
    }}

    {{ name:     "num_managers"
      desc:     "Value of the num_managers parameter."
      swaccess: "ro"
      hwaccess: "hwo"
      hwqe:     "true"
      hwext:    "true"
      fields: [
        {{ bits: "31:0", name: "num_managers", desc: "Value of the num_managers parameter." }}
      ]
    }}

    {{ name:     "addr_width"
      desc:     "Value of the addr_width parameter."
      swaccess: "ro"
      hwaccess: "hwo"
      hwqe:     "true"
      hwext:    "true"
      fields: [
        {{ bits: "31:0", name: "addr_width", desc: "Value of the addr_width parameter." }}
      ]
    }}

    {{ name:     "data_width"
      desc:     "Value of the data_width parameter."
      swaccess: "ro"
      hwaccess: "hwo"
      hwqe:     "true"
      hwext:    "true"
      fields: [
        {{ bits: "31:0", name: "data_width", desc: "Value of the data_width parameter." }}
      ]
    }}

    {{ name:     "id_width"
      desc:     "Value of the id_width parameter."
      swaccess: "ro"
      hwaccess: "hwo"
      hwqe:     "true"
      hwext:    "true"
      fields: [
        {{ bits: "31:0", name: "id_width", desc: "Value of the id_width parameter." }}
      ]
    }}

    {{ name:     "user_width"
      desc:     "Value of the user_width parameter."
      swaccess: "ro"
      hwaccess: "hwo"
      hwqe:     "true"
      hwext:    "true"
      fields: [
        {{ bits: "31:0", name: "user_width", desc: "Value of the user_width parameter." }}
      ]
    }}

    {{ name:     "num_pending"
      desc:     "Value of the num_pending parameter."
      swaccess: "ro"
      hwaccess: "hwo"
      hwqe:     "true"
      hwext:    "true"
      fields: [
        {{ bits: "31:0", name: "num_pending", desc: "Value of the num_pending parameter." }}
      ]
    }}

    {{ name:     "w_buffer_depth"
      desc:     "Value of the w_buffer_depth parameter."
      swaccess: "ro"
      hwaccess: "hwo"
      hwqe:     "true"
      hwext:    "true"
      fields: [
        {{ bits: "31:0", name: "w_buffer_depth", desc: "Value of the w_buffer_depth parameter." }}
      ]
    }}

    {{ name:     "num_addr_regions"
      desc:     "Value of the num_addr_regions parameter."
      swaccess: "ro"
      hwaccess: "hwo"
      hwqe:     "true"
      hwext:    "true"
      fields: [
        {{ bits: "31:0", name: "num_addr_regions", desc: "Value of the num_addr_regions parameter." }}
      ]
    }}

    {{ name:     "period_width"
      desc:     "Value of the period_width parameter."
      swaccess: "ro"
      hwaccess: "hwo"
      hwqe:     "true"
      hwext:    "true"
      fields: [
        {{ bits: "31:0", name: "period_width", desc: "Value of the period_width parameter." }}
      ]
    }}

    {{ name:     "budget_width"
      desc:     "Value of the budget_width parameter."
      swaccess: "ro"
      hwaccess: "hwo"
      hwqe:     "true"
      hwext:    "true"
      fields: [
        {{ bits: "31:0", name: "budget_width", desc: "Value of the budget_width parameter." }}
      ]
    }}

    {{ name:     "max_num_managers"
      desc:     "Value of the max_num_managers parameter."
      swaccess: "ro"
      resval:   "{num_managers}"
      fields: [
        {{ bits: "31:0", name: "max_num_managers", desc: "Value of the max_num_managers parameter." }}
      ]
    }}

  ]
}}
'''

PER_MGR_REGS = '''
    {{ multireg:
      {{ name:     "start_addr_sub_low"
        desc:     "The lower 32bit of the start address."
        swaccess: "wo"
        hwaccess: "hro"
        count:    "NumReg"
        cname:    "start_addr_sub_low"
        resval:   "0"
        fields: [
          {{ bits: "31:0", name: "write_budget", desc: "The lower 32bit of the start address." }}
        ]
      }}
    }}

    {{ multireg:
      {{ name:     "start_addr_sub_high"
        desc:     "The higher 32bit of the start address."
        swaccess: "wo"
        hwaccess: "hro"
        count:    "NumReg"
        cname:    "start_addr_sub_high"
        resval:   "0"
        fields: [
          {{ bits: "31:0", name: "write_budget", desc: "The higher 32bit of the start address." }}
        ]
      }}
    }}

    {{ multireg:
      {{ name:     "end_addr_sub_low"
        desc:     "The lower 32bit of the end address."
        swaccess: "wo"
        hwaccess: "hro"
        count:    "NumReg"
        cname:    "end_addr_sub_low"
        resval:   "0"
        fields: [
          {{ bits: "31:0", name: "write_budget", desc: "The lower 32bit of the end address." }}
        ]
      }}
    }}

    {{ multireg:
      {{ name:     "end_addr_sub_high"
        desc:     "The higher 32bit of the end address."
        swaccess: "wo"
        hwaccess: "hro"
        count:    "NumReg"
        cname:    "end_addr_sub_high"
        resval:   "0"
        fields: [
          {{ bits: "31:0", name: "write_budget", desc: "The higher 32bit of the end address." }}
        ]
      }}
    }}

    {{ multireg:
      {{ name:     "write_budget"
        desc:     "The budget for writes."
        swaccess: "wo"
        hwaccess: "hro"
        count:    "NumReg"
        cname:    "write_budget"
        resval:   "0"
        fields: [
          {{ bits: "31:0", name: "write_budget", desc: "The budget for writes." }}
        ]
      }}
    }}

    {{ multireg:
      {{ name:     "read_budget"
        desc:     "The budget for reads."
        swaccess: "wo"
        hwaccess: "hro"
        count:    "NumReg"
        cname:    "read_budget"
        resval:   "0"
        fields: [
          {{ bits: "31:0", name: "read_budget", desc: "The budget for reads." }}
        ]
      }}
    }}

    {{ multireg:
      {{ name:     "write_period"
        desc:     "The period for writes."
        swaccess: "wo"
        hwaccess: "hro"
        count:    "NumReg"
        cname:    "write_period"
        resval:   "0"
        fields: [
          {{ bits: "31:0", name: "write_period", desc: "The period for writes." }}
        ]
      }}
    }}

    {{ multireg:
      {{ name:     "read_period"
        desc:     "The period for reads."
        swaccess: "wo"
        hwaccess: "hro"
        count:    "NumReg"
        cname:    "read_period"
        resval:   "0"
        fields: [
          {{ bits: "31:0", name: "read_period", desc: "The period for reads." }}
        ]
      }}
    }}

    {{ multireg:
      {{ name:     "write_budget_left"
        desc:     "The budget left for writes."
        swaccess: "ro"
        hwaccess: "hwo"
        hwqe:     "true"
        hwext:    "true"
        count:    "NumReg"
        cname:    "write_budget_left"
        resval:   "0"
        fields: [
          {{ bits: "31:0", name: "write_budget_left", desc: "The budget left for writes." }}
        ]
      }}
    }}

    {{ multireg:
      {{ name:     "read_budget_left"
        desc:     "The budget left for reads."
        swaccess: "ro"
        hwaccess: "hwo"
        hwqe:     "true"
        hwext:    "true"
        count:    "NumReg"
        cname:    "read_budget_left"
        resval:   "0"
        fields: [
          {{ bits: "31:0", name: "read_budget_left", desc: "The budget left for reads." }}
        ]
      }}
    }}

    {{ multireg:
      {{ name:     "write_period_left"
        desc:     "The period left for writes."
        swaccess: "ro"
        hwaccess: "hwo"
        hwqe:     "true"
        hwext:    "true"
        count:    "NumReg"
        cname:    "write_period_left"
        resval:   "0"
        fields: [
          {{ bits: "31:0", name: "write_period_left", desc: "The period left for writes." }}
        ]
      }}
    }}

    {{ multireg:
      {{ name:     "read_period_left"
        desc:     "The period left for reads."
        swaccess: "ro"
        hwaccess: "hwo"
        hwqe:     "true"
        hwext:    "true"
        count:    "NumReg"
        cname:    "read_period_left"
        resval:   "0"
        fields: [
          {{ bits: "31:0", name: "read_period_left", desc: "The period left for reads." }}
        ]
      }}
    }}
'''

script_name, version_file, num_managers, num_subordinates = sys.argv

with open(version_file, encoding='utf8') as v:
  [major, minor, patch] = [int (n) for n in v.read().split('.')]

print(REG_STR.format(
    script_name=script_name,
    num_managers=num_managers,
    num_subordinates=num_subordinates,
    num_regsters=int(num_managers) * int(num_subordinates),
    #per_mgr_regs=''.join([PER_MGR_REGS.format(mgr_num = i) for i in range(int(num_managers))]))
    per_mgr_regs=PER_MGR_REGS.format(),
    major=major,
    minor=minor,
    patch=patch
  )
)
