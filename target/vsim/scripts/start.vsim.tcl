# Copyright 2022 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
# Licensed under Solderpad Hardware License, Version 0.51, see LICENSE for details.
#
# Authors:
# - Thomas Benz <tbenz@iis.ee.ethz.ch>
# - Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

# Record signals.
log -r /*

# Add design hierarchy to the Wave window.
add wave -r /*

# Run simulation.
run -all

# Fit the entire run in the Wave window.
wave zoom full
