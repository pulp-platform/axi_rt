# Copyright 2024 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Authors:
# Alessandro Ottaviano <aottaviano@iis.ee.ethz.ch>

# Add packaged AXI RT IP to Vivado IP catalog and instantiate it in a block
# design. This script is meant to be used during a block design.

set_property ip_repo_paths $AXIRTIP_DIR [current_project]
update_ip_catalog

create_bd_cell -type ip -vlnv ethz.ch:user:axi_rt_unit_top_xilinx_ip:1.0 axirt_ip_0

