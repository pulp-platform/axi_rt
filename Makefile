# Copyright 2025 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Chaoqun Liang <chaoqun.liang@unibo.it>

TMU_ROOT ?= $(shell pwd)
BENDER	 ?= bender -d $(TMU_ROOT)

clean:
	rm -rf .bender
	rm -f bender
	rm -f Bender.lock

include axi_tmu.mk