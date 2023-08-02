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
AXIRT_NUM_MGRS ?= 8
AXIRT_NUM_SUBS ?= 2

AXIRTROOT  ?= $(shell $(BENDER) path axi_rt)


# Reconfigure Registers
$(AXIRTROOT)/src/regs/axi_rt.hjson: src/regs/gen_hjson.py $(AXIRTROOT)/VERSION
	$(PYTHON3) $? $(AXIRT_NUM_MGRS) $(AXIRT_NUM_SUBS) > $@


.PHONY: axirt_regs

axirt_regs: $(AXIRTROOT)/src/regs/axi_rt.hjson $(REGTOOL)
	$(REGTOOL) -r -t $(AXIRTROOT)/src/regs $<
	$(REGTOOL) -D -o $(AXIRTROOT)/sw/include/axi_rt_regs.h $<


# Simulation compile script
$(AXIRTROOT)/scripts/compile.vsim.tcl: axirt_regs $(AXIRTROOT)/Bender.yml $(AXIRTROOT)/Bender.lock
	$(BENDER) script vsim -t rtl -t test > $@
