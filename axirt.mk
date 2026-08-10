# Copyright 2023 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Authors:
# - Thomas Benz <tbenz@iis.ee.ethz.ch>

# Import this GNU Make fragment in your project's makefile to regenerate and
# reconfigure these IPs. You can modify the original RTL, configuration, and
# templates from your project without entering this dependency repo by adding
# build targets for them. To build the IPs, `make axirt`.

# You may need to adapt these environment variables to your configuration.
BENDER     ?= bender
PYTHON3    ?= python3
REGTOOL    ?= $(shell $(BENDER) path register_interface)/vendor/lowrisc_opentitan/util/regtool.py

# Default config
AXIRT_NUM_MGRS ?= 1
AXIRT_NUM_SUBS ?= 16

AXIRTXILROOT  = $(AXIRTROOT)/target/xilinx
AXIRTVSIMROOT = $(AXIRTROOT)/target/vsim

# Reconfigure Registers
$(AXIRTROOT)/src/regs/axi_rt.hjson: $(AXIRTROOT)/src/regs/gen_hjson.py $(AXIRTROOT)/VERSION
	$(PYTHON3) $(AXIRTROOT)/src/regs/gen_hjson.py $(AXIRTROOT)/VERSION $(AXIRT_NUM_MGRS) $(AXIRT_NUM_SUBS) > $@


.PHONY: axirt_regs clean_axirt_regs

axirt_regs: $(AXIRTROOT)/src/regs/axi_rt.hjson $(REGTOOL)
	$(PYTHON3) $(REGTOOL) -r -t $(AXIRTROOT)/src/regs $<
	$(PYTHON3) $(REGTOOL) -D -o $(AXIRTROOT)/sw/include/regs/axi_rt.h $<

clean_axirt_regs:
	rm -f $(AXIRTROOT)/src/regs/axi_rt.hjson
	rm -f $(AXIRTROOT)/src/regs/axi_rt_reg_pkg.sv
	rm -f $(AXIRTROOT)/src/regs/axi_rt_reg_top.sv
	rm -f $(AXIRTROOT)/sw/include/regs/axi_rt.h

# Simulation
include $(AXIRTVSIMROOT)/vsim.mk

# Emulation
include $(AXIRTXILROOT)/xilinx.mk
