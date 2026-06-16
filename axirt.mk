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
# `PEAKRDL` defaults to the bare executable (e.g. from a `pip install peakrdl`).
# To use the `uv`-managed, version-pinned environment from `pyproject.toml` /
# `uv.lock` instead, invoke `make PEAKRDL="uv run peakrdl" axirt_regs`.
BENDER     ?= bender
PEAKRDL    ?= peakrdl

# Default config
AXIRT_NUM_MGRS ?= 8
AXIRT_NUM_SUBS ?= 2

# Version fields parsed from the `VERSION` file (major.minor.patch)
AXIRT_VER_MAJOR := $(shell cut -d. -f1 $(AXIRTROOT)/VERSION)
AXIRT_VER_MINOR := $(shell cut -d. -f2 $(AXIRTROOT)/VERSION)
AXIRT_VER_PATCH := $(shell cut -d. -f3 $(AXIRTROOT)/VERSION)

AXIRTXILROOT  = $(AXIRTROOT)/target/xilinx

# Elaboration parameters passed to PeakRDL (counts + version)
AXIRT_RDL        = $(AXIRTROOT)/src/regs/axi_rt.rdl
PEAKRDL_PARAMS   = -P NumMrg=$(AXIRT_NUM_MGRS) -P NumSub=$(AXIRT_NUM_SUBS) \
                   -P MajorVer=$(AXIRT_VER_MAJOR) -P MinorVer=$(AXIRT_VER_MINOR) \
                   -P PatchVer=$(AXIRT_VER_PATCH)


.PHONY: axirt_regs

# Generate the APB register block (SystemVerilog) and the SW C header.
axirt_regs: $(AXIRT_RDL) $(AXIRTROOT)/VERSION
	$(PEAKRDL) regblock $(AXIRT_RDL) --cpuif apb4-flat --default-reset arst_n \
	    $(PEAKRDL_PARAMS) -o $(AXIRTROOT)/src/regs
	$(PEAKRDL) c-header $(AXIRT_RDL) $(PEAKRDL_PARAMS) \
	    -o $(AXIRTROOT)/sw/include/regs/axi_rt.h


# Simulation compile script
$(AXIRTROOT)/scripts/compile.vsim.tcl: axirt_regs $(AXIRTROOT)/Bender.yml $(AXIRTROOT)/Bender.lock
	$(BENDER) script vsim -t test > $@

# Emulation
include $(AXIRTXILROOT)/xilinx.mk
