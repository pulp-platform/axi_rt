# Copyright 2023 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Authors:
# - Thomas Benz <tbenz@iis.ee.ethz.ch>

BENDER    ?= bender
AXIRTROOT ?= .

include axirt.mk

# default target: make all
all: axirt_regs $(AXIRTROOT)/scripts/compile.vsim.tcl

# clean generated files
clean:
	rm -f $(AXIRTROOT)/scripts/compile.vsim.tcl
