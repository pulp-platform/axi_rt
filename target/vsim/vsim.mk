# Copyright 2026 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Authors:
# - Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

AXIRTVSIMROOT ?= .
PYTHON  	  ?= python3
BENDER   	  ?= bender

# QuestaSim options
VSIM 		 ?= vsim

VSIM_SRC  	 = $(AXIRTVSIMROOT)/src
VSIM_STIMULI = $(AXIRTVSIMROOT)/stimuli
VSIM_RUN  	 = $(AXIRTVSIMROOT)/run
VSIM_WORK 	 = $(VSIM_RUN)/work

VLOG_ARGS = -work $(VSIM_WORK)
VLOG_ARGS += -suppress vlog-2583
VLOG_ARGS += -suppress vlog-13314
VLOG_ARGS += -suppress vlog-13233
VLOG_ARGS += -timescale 1ns/1ps

VSIM_FLAGS = -work $(VSIM_WORK)
VSIM_FLAGS += -suppress 3009
VSIM_FLAGS += -suppress 8386
VSIM_FLAGS += -suppress 13314
VSIM_FLAGS += -quiet
VSIM_FLAGS += -64
VSIM_FLAGS += -voptargs=+acc
VSIM_FLAGS += -voptargs=+vpi

VSIM_FLAGS_GUI = -voptargs=+acc

VSIM_COMMON_CMD = log -r /*; run -a;

TB_DUT ?= tb_axi_rt_unit_top

# Stimuli generation
AXIRT_STIM_GEN     = $(AXIRTVSIMROOT)/../../scripts/gen_stimuli.py
STIM_NUM_MASTERS  ?= 2
STIM_NUM_TX       ?= 4
STIM_MIN_LEN      ?= 15
STIM_MAX_LEN      ?= 15
STIM_SEED         ?= 0

.PHONY: axirt-vsim-gen-stimuli axirt-vsim-compile axirt-vsim-run axirt-vsim-run-batch axirt-vsim-clean

axirt-vsim-gen-stimuli:
	mkdir -p $(VSIM_STIMULI)
	for m in $$(seq 0 $$(( $(STIM_NUM_MASTERS) - 1 ))); do \
		f=`printf '%04x' $$m`; s=$$(( $(STIM_SEED) + $$m )); \
		$(PYTHON) $(AXIRT_STIM_GEN) $(STIM_NUM_TX) $(STIM_MIN_LEN) $(STIM_MAX_LEN) 0 $$s > $(VSIM_STIMULI)/axi_rt_unit_$$f.reads.txt; \
		$(PYTHON) $(AXIRT_STIM_GEN) $(STIM_NUM_TX) $(STIM_MIN_LEN) $(STIM_MAX_LEN) 1 $$s > $(VSIM_STIMULI)/axi_rt_unit_$$f.writes.txt; \
	done

$(VSIM_RUN)/compile.axirt.vsim.tcl: $(AXIRTVSIMROOT)/vsim.mk
	mkdir -p $(VSIM_RUN)
	$(BENDER) script vsim -t test --vlog-arg="$(VLOG_ARGS)" > $@

axirt-vsim-compile: $(VSIM_RUN)/compile.axirt.vsim.tcl axirt-vsim-gen-stimuli
	cd $(VSIM_RUN) && $(VSIM) -c $(VSIM_FLAGS) -do "source $<; quit"

axirt-vsim-run: axirt-vsim-compile
	cd $(VSIM_RUN) && $(VSIM) $(VSIM_FLAGS) $(VSIM_FLAGS_GUI) +STIM_DIR=$(VSIM_STIMULI) $(TB_DUT) -do "$(VSIM_COMMON_CMD)"

axirt-vsim-run-batch: axirt-vsim-compile
	cd $(VSIM_RUN) && $(VSIM) -c $(VSIM_FLAGS) +STIM_DIR=$(VSIM_STIMULI) $(TB_DUT) -do "$(VSIM_COMMON_CMD) quit"

axirt-vsim-clean:
	rm -rf $(VSIM_RUN)
	rm -rf $(VSIM_STIMULI)