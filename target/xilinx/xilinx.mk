# Copyright 2024 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Authors:
# - Alessandro Ottaviano <aottaviano@ethz.ch>

AXIRTXILROOT ?= .
PYTHON       := python3

# Vivado options
VIVADO       ?= vitis-2022.1 vivado
AXIRTXILPROJ := axirt_ip
VIVADO_MODE  := batch

XILINX_BOARD   ?= vcu128

ifeq ($(XILINX_BOARD),vcu128)
	XILINX_PART       := xcvu37p-fsvh2892-2L-e
	XILINX_BOARD_LONG := xilinx.com:vcu128:part0:1.0
endif

VIVADO_ENV := \
    XILINX_PROJECT=$(AXIRTXILPROJ) \
    XILINX_BOARD=$(XILINX_BOARD) \
    XILINX_PART=$(XILINX_PART)

# Generate IP top level according to parameterization. Parameterization is taken
# from the main makefrag in the repo root (`axirt.mk`)

$(AXIRTXILROOT)/src/axi_rt_unit_top_xilinx_ip.v:
	$(PYTHON) $(AXIRTXILROOT)/gen/gen_axi_rt_xilinx.py $(AXIRT_NUM_MGRS) $(AXIRT_NUM_SUBS) > $@

# Source files
$(AXIRTXILROOT)/scripts/compile.axirt.xilinx.tcl:
	$(BENDER) script vivado -t rtl -t fpga > $@

# Package IP
$(AXIRTXILROOT)/$(AXIRTXILPROJ).xci: $(AXIRTXILROOT)/$(AXIRTXILPROJ).xpr

$(AXIRTXILROOT)/$(AXIRTXILPROJ).xpr:
	cd $(AXIRTXILROOT) && $(VIVADO_ENV) $(VIVADO) -mode $(VIVADO_MODE) -source $(AXIRTROOT)/scripts/run.tcl

.PHONY: axirt-xil-all axirt-xil-clean

axirt-xil-all: $(AXIRTXILROOT)/scripts/compile.axirt.xilinx.tcl $(AXIRTXILROOT)/$(AXIRTXILPROJ).xci

axirt-xil-clean:
	rm -rf $(AXIRTXILROOT)/.Xil
	rm -rf $(AXIRTXILROOT)/*.log
	rm -rf $(AXIRTXILROOT)/*.xml
	rm -rf $(AXIRTXILROOT)/vivado*
	rm -rf $(AXIRTXILROOT)/axirt_ip*
