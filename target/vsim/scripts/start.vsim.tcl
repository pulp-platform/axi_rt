# Copyright 2022 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
# Licensed under Solderpad Hardware License, Version 0.51, see LICENSE for details.
#
# Authors:
# - Thomas Benz <tbenz@iis.ee.ethz.ch>

vsim -voptargs=+acc -t 1ps tb_axi_rt_unit_top
log -r /*
