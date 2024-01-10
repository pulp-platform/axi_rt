# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

from mako.template import Template
import math
import re
import sys

script_name, num_managers, num_subordinates = sys.argv

iw = 4

def clog2(x):
    return math.ceil(math.log2(int(x)))

rt_template = Template(filename='./target/xilinx/gen/axi_rt_unit_top_xilinx_ip.v.tpl')
string = rt_template.render(
    rtcfg_num_mngrs   = num_managers,
    rtcfg_num_regions = num_subordinates,
    rtcfg_num_pending = 32,
    rtcfg_buf_depth   = 32,
    rtcfg_prd_width   = 32,
    rtcfg_bdgt_width  = 32,
    rtcfg_cut_paths   = 1,
    rtcfg_en_checks   = 0,
    rtcfg_cut_decerr  = 0,
    rtcfg_iw          = iw,
    rtcfg_aw          = 48,
    rtcfg_dw          = 64,
    rtcfg_uw          = 4,
    rtcfg_law         = 32,
    rtcfg_ldw         = 32,
    rtcfg_riw         = iw + clog2(num_managers),
)
string = re.sub(r'\s+$', '', string, flags=re.M)
print(string)
