# Copyright 2024 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Authors:
# Alessandro Ottaviano <aottaviano@iis.ee.ethz.ch>
# Cyril Koenig <cykoenig@iis.ee.ethz.ch>

# Package AXI RT IP in Xilinx environment
# Change XILINX_PART according to the target board

# Create project
set project $::env(XILINX_PROJECT)
set part $::env(XILINX_PART)
set ip_root_dir $project

create_project $project . -force -part $part
set_property XPM_LIBRARIES XPM_MEMORY [current_project]

# set number of threads to 8 (maximum, unfortunately)
set_param general.maxThreads 8

# Define sources
source scripts/compile.axirt.xilinx.tcl

# Set top level
set_property top axi_rt_unit_top_xilinx_ip [current_fileset]

# Add constraints
add_files -fileset constrs_1 constraints/axirt_ip.xdc
#set_property USED_IN {synthesis out_of_context} [get_files constraints/axirt_ip.xdc]

# Synthesize
# Attention SFCU is only used because of Carfield's structure
update_compile_order -fileset sources_1
synth_design -rtl -name rtl_1 -sfcu

# Package IP

## Define package name and vendor
file mkdir $ip_root_dir
ipx::package_project -root_dir $ip_root_dir -vendor ethz.ch -library user -taxonomy /UserIP -import_files -set_current true

## Clock interface
ipx::add_bus_interface clk_i [ipx::current_core]
set_property abstraction_type_vlnv xilinx.com:interface:aximm_rtl:1.0 [ipx::get_bus_interfaces clk_i -of_objects [ipx::current_core]]
set_property bus_type_vlnv xilinx.com:interface:aximm:1.0 [ipx::get_bus_interfaces clk_i -of_objects [ipx::current_core]]
set_property interface_mode master [ipx::get_bus_interfaces clk_i -of_objects [ipx::current_core]]
ipx::add_bus_parameter NUM_READ_OUTSTANDING [ipx::get_bus_interfaces clk_i -of_objects [ipx::current_core]]
ipx::add_bus_parameter NUM_WRITE_OUTSTANDING [ipx::get_bus_interfaces clk_i -of_objects [ipx::current_core]]
set_property abstraction_type_vlnv xilinx.com:signal:clock_rtl:1.0 [ipx::get_bus_interfaces clk_i -of_objects [ipx::current_core]]
set_property bus_type_vlnv xilinx.com:signal:clock:1.0 [ipx::get_bus_interfaces clk_i -of_objects [ipx::current_core]]
set_property display_name clk_i [ipx::get_bus_interfaces clk_i -of_objects [ipx::current_core]]
set_property description {clock of AXI RT unit} [ipx::get_bus_interfaces clk_i -of_objects [ipx::current_core]]
set_property interface_mode slave [ipx::get_bus_interfaces clk_i -of_objects [ipx::current_core]]
ipx::add_port_map CLK [ipx::get_bus_interfaces clk_i -of_objects [ipx::current_core]]
set_property physical_name clk_i [ipx::get_port_maps CLK -of_objects [ipx::get_bus_interfaces clk_i -of_objects [ipx::current_core]]]

## Reset interface
ipx::add_bus_interface rst_ni [ipx::current_core]
set_property abstraction_type_vlnv xilinx.com:signal:reset_rtl:1.0 [ipx::get_bus_interfaces rst_ni -of_objects [ipx::current_core]]
set_property bus_type_vlnv xilinx.com:signal:reset:1.0 [ipx::get_bus_interfaces rst_ni -of_objects [ipx::current_core]]
set_property display_name rst_ni [ipx::get_bus_interfaces rst_ni -of_objects [ipx::current_core]]
set_property description {Reset of AXI-RT, active low} [ipx::get_bus_interfaces rst_ni -of_objects [ipx::current_core]]
ipx::add_port_map RST [ipx::get_bus_interfaces rst_ni -of_objects [ipx::current_core]]
set_property physical_name rst_ni [ipx::get_port_maps RST -of_objects [ipx::get_bus_interfaces rst_ni -of_objects [ipx::current_core]]]

## AXI manager interfaces
ipx::add_bus_interface m_axi_rt [ipx::current_core]
set_property abstraction_type_vlnv xilinx.com:interface:aximm_rtl:1.0 [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property bus_type_vlnv xilinx.com:interface:aximm:1.0 [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property interface_mode master [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property display_name m_axi_rt [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property description {AXI RT manager ports} [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
ipx::add_bus_parameter NUM_READ_OUTSTANDING [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
ipx::add_bus_parameter NUM_WRITE_OUTSTANDING [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
ipx::add_port_map WLAST [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_wlast_o [ipx::get_port_maps WLAST -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map BREADY [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_bready_o [ipx::get_port_maps BREADY -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map AWLEN [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_awlen_o [ipx::get_port_maps AWLEN -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map AWQOS [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_awqos_o [ipx::get_port_maps AWQOS -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map AWREADY [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_awready_i [ipx::get_port_maps AWREADY -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map ARBURST [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_arburst_o [ipx::get_port_maps ARBURST -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map AWPROT [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_awprot_o [ipx::get_port_maps AWPROT -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map RRESP [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_rresp_i [ipx::get_port_maps RRESP -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map ARPROT [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_arprot_o [ipx::get_port_maps ARPROT -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map RVALID [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_rvalid_i [ipx::get_port_maps RVALID -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map ARLOCK [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_arlock_o [ipx::get_port_maps ARLOCK -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map AWID [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_awid_o [ipx::get_port_maps AWID -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map RLAST [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_rlast_i [ipx::get_port_maps RLAST -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map ARID [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_arid_o [ipx::get_port_maps ARID -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map AWCACHE [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_awcache_o [ipx::get_port_maps AWCACHE -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map WREADY [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_wready_i [ipx::get_port_maps WREADY -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map WSTRB [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_wstrb_o [ipx::get_port_maps WSTRB -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map BRESP [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_bresp_i [ipx::get_port_maps BRESP -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map BID [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_bid_i [ipx::get_port_maps BID -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map AWUSER [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_awuser_o [ipx::get_port_maps AWUSER -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map ARLEN [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_arlen_o [ipx::get_port_maps ARLEN -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map ARQOS [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_arqos_o [ipx::get_port_maps ARQOS -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map RDATA [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_rdata_i [ipx::get_port_maps RDATA -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map BVALID [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_bvalid_i [ipx::get_port_maps BVALID -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map ARCACHE [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_arcache_o [ipx::get_port_maps ARCACHE -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map AWVALID [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_awvalid_o [ipx::get_port_maps AWVALID -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map ARSIZE [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_arsize_o [ipx::get_port_maps ARSIZE -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map WDATA [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_wdata_o [ipx::get_port_maps WDATA -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map ARUSER [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_aruser_o [ipx::get_port_maps ARUSER -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map AWSIZE [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_awsize_o [ipx::get_port_maps AWSIZE -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map RID [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_rid_i [ipx::get_port_maps RID -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map ARADDR [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_araddr_o [ipx::get_port_maps ARADDR -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map AWADDR [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_awaddr_o [ipx::get_port_maps AWADDR -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map ARREADY [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_arready_i [ipx::get_port_maps ARREADY -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map ARVALID [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_arvalid_o [ipx::get_port_maps ARVALID -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map AWLOCK [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_awlock_o [ipx::get_port_maps AWLOCK -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map AWBURST [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_awburst_o [ipx::get_port_maps AWBURST -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map RREADY [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_rready_o [ipx::get_port_maps RREADY -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map WVALID [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property physical_name m_axi_rt_wvalid_o [ipx::get_port_maps WVALID -of_objects [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]]

## AXI subordinate interfaces
ipx::add_bus_interface s_axi_rt [ipx::current_core]
set_property abstraction_type_vlnv xilinx.com:interface:aximm_rtl:1.0 [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property bus_type_vlnv xilinx.com:interface:aximm:1.0 [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property display_name s_axi_rt [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property description {AXI RT subordinate ports} [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
ipx::add_bus_parameter NUM_READ_OUTSTANDING [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
ipx::add_bus_parameter NUM_WRITE_OUTSTANDING [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
ipx::add_port_map WLAST [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_wlast_i [ipx::get_port_maps WLAST -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map BREADY [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_bready_i [ipx::get_port_maps BREADY -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map AWLEN [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_awlen_i [ipx::get_port_maps AWLEN -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map AWQOS [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_awqos_i [ipx::get_port_maps AWQOS -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map AWREADY [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_awready_o [ipx::get_port_maps AWREADY -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map ARBURST [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_arburst_i [ipx::get_port_maps ARBURST -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map AWPROT [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_awprot_i [ipx::get_port_maps AWPROT -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map RRESP [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_rresp_o [ipx::get_port_maps RRESP -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map ARPROT [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_arprot_i [ipx::get_port_maps ARPROT -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map RVALID [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_rvalid_o [ipx::get_port_maps RVALID -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map ARLOCK [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_arlock_i [ipx::get_port_maps ARLOCK -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map AWID [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_awid_i [ipx::get_port_maps AWID -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map RLAST [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_rlast_o [ipx::get_port_maps RLAST -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map ARID [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_arid_i [ipx::get_port_maps ARID -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map AWCACHE [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_awcache_i [ipx::get_port_maps AWCACHE -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map WREADY [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_wready_o [ipx::get_port_maps WREADY -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map WSTRB [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_wstrb_i [ipx::get_port_maps WSTRB -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map BRESP [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_bresp_o [ipx::get_port_maps BRESP -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map BID [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_bid_o [ipx::get_port_maps BID -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map AWUSER [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_awuser_i [ipx::get_port_maps AWUSER -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map ARLEN [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_arlen_i [ipx::get_port_maps ARLEN -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map ARQOS [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_arqos_i [ipx::get_port_maps ARQOS -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map RDATA [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_rdata_o [ipx::get_port_maps RDATA -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map BVALID [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_bvalid_o [ipx::get_port_maps BVALID -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map ARCACHE [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_arcache_i [ipx::get_port_maps ARCACHE -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map RREADY [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_rready_i [ipx::get_port_maps RREADY -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map AWVALID [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_awvalid_i [ipx::get_port_maps AWVALID -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map ARSIZE [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_arsize_i [ipx::get_port_maps ARSIZE -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map WDATA [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_wdata_i [ipx::get_port_maps WDATA -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map ARUSER [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_aruser_i [ipx::get_port_maps ARUSER -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map AWSIZE [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_awsize_i [ipx::get_port_maps AWSIZE -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map RID [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_rid_o [ipx::get_port_maps RID -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map ARADDR [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_araddr_i [ipx::get_port_maps ARADDR -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map AWADDR [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_awaddr_i [ipx::get_port_maps AWADDR -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map ARREADY [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_arready_o [ipx::get_port_maps ARREADY -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map WVALID [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_wvalid_i [ipx::get_port_maps WVALID -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map ARVALID [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_arvalid_i [ipx::get_port_maps ARVALID -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map AWLOCK [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_awlock_i [ipx::get_port_maps AWLOCK -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]
ipx::add_port_map AWBURST [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]
set_property physical_name s_axi_rt_awburst_i [ipx::get_port_maps AWBURST -of_objects [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]]

# AXI lite cfg interfaces
ipx::add_bus_interface s_axi_lite_rt_cfg [ipx::current_core]
set_property abstraction_type_vlnv xilinx.com:interface:aximm_rtl:1.0 [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]
set_property bus_type_vlnv xilinx.com:interface:aximm:1.0 [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]
set_property display_name s_axi_lite_rt_cfg [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]
set_property description {AXI RT configuration port} [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]
ipx::add_bus_parameter NUM_READ_OUTSTANDING [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]
ipx::add_bus_parameter NUM_WRITE_OUTSTANDING [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]
ipx::add_port_map RREADY [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]
set_property physical_name s_axi_lite_rt_rready_i [ipx::get_port_maps RREADY -of_objects [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]]
ipx::add_port_map BREADY [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]
set_property physical_name s_axi_lite_rt_bready_i [ipx::get_port_maps BREADY -of_objects [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]]
ipx::add_port_map AWVALID [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]
set_property physical_name s_axi_lite_rt_awvalid_i [ipx::get_port_maps AWVALID -of_objects [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]]
ipx::add_port_map AWPROT [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]
set_property physical_name s_axi_lite_rt_awprot_i [ipx::get_port_maps AWPROT -of_objects [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]]
ipx::add_port_map WDATA [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]
set_property physical_name s_axi_lite_rt_wdata_i [ipx::get_port_maps WDATA -of_objects [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]]
ipx::add_port_map RRESP [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]
set_property physical_name s_axi_lite_rt_rresp_o [ipx::get_port_maps RRESP -of_objects [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]]
ipx::add_port_map ARPROT [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]
set_property physical_name s_axi_lite_rt_arprot_i [ipx::get_port_maps ARPROT -of_objects [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]]
ipx::add_port_map RVALID [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]
set_property physical_name s_axi_lite_rt_rvalid_o [ipx::get_port_maps RVALID -of_objects [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]]
ipx::add_port_map ARADDR [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]
set_property physical_name s_axi_lite_rt_araddr_i [ipx::get_port_maps ARADDR -of_objects [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]]
ipx::add_port_map AWADDR [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]
set_property physical_name s_axi_lite_rt_awaddr_i [ipx::get_port_maps AWADDR -of_objects [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]]
ipx::add_port_map ARREADY [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]
set_property physical_name s_axi_lite_rt_arready_o [ipx::get_port_maps ARREADY -of_objects [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]]
ipx::add_port_map WVALID [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]
set_property physical_name s_axi_lite_rt_wvalid_i [ipx::get_port_maps WVALID -of_objects [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]]
ipx::add_port_map ARVALID [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]
set_property physical_name s_axi_lite_rt_arvalid_i [ipx::get_port_maps ARVALID -of_objects [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]]
ipx::add_port_map WSTRB [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]
set_property physical_name s_axi_lite_rt_wstrb_i [ipx::get_port_maps WSTRB -of_objects [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]]
ipx::add_port_map RDATA [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]
set_property physical_name s_axi_lite_rt_rdata_o [ipx::get_port_maps RDATA -of_objects [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]]
ipx::add_port_map BVALID [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]
set_property physical_name s_axi_lite_rt_bvalid_o [ipx::get_port_maps BVALID -of_objects [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]]
ipx::add_port_map AWREADY [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]
set_property physical_name s_axi_lite_rt_awready_o [ipx::get_port_maps AWREADY -of_objects [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]]
ipx::add_port_map WREADY [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]
set_property physical_name s_axi_lite_rt_wready_o [ipx::get_port_maps WREADY -of_objects [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]]
ipx::add_port_map BRESP [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]
set_property physical_name s_axi_lite_rt_bresp_o [ipx::get_port_maps BRESP -of_objects [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]]

# Associate clock to AXI interfaces
ipx::associate_bus_interfaces -busif m_axi_rt -clock clk_i [ipx::current_core]
ipx::associate_bus_interfaces -busif s_axi_rt -clock clk_i [ipx::current_core]
ipx::associate_bus_interfaces -busif s_axi_lite_rt_cfg -clock clk_i [ipx::current_core]

## Address spaces

### AXI managers
ipx::add_address_space m_axi_rt [ipx::current_core]
set_property master_address_space_ref m_axi_rt [ipx::get_bus_interfaces m_axi_rt -of_objects [ipx::current_core]]
set_property range 16E [ipx::get_address_spaces m_axi_rt -of_objects [ipx::current_core]]
set_property width 49 [ipx::get_address_spaces m_axi_rt -of_objects [ipx::current_core]]

### AXI subordinates
ipx::add_memory_map s_axi_rt [ipx::current_core]
set_property slave_memory_map_ref s_axi_rt [ipx::get_bus_interfaces s_axi_rt -of_objects [ipx::current_core]]

### AXI Lite
ipx::add_memory_map s_axi_lite_rt_cfg [ipx::current_core]
set_property slave_memory_map_ref s_axi_lite_rt_cfg [ipx::get_bus_interfaces s_axi_lite_rt_cfg -of_objects [ipx::current_core]]

# Package
set_property core_revision 2 [ipx::current_core]
ipx::update_source_project_archive -component [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::check_integrity [ipx::current_core]
# TODO monitor these warnings. awlen and arlen are set to 8 so strange that it complains.
#WARNING: [IP_Flow 19-5469] The value of the arlen and awlen ports on m_axi_rt don't correspond to a known AXI Protocol. Known lengths are 0, 4 and 8.
#WARNING: [IP_Flow 19-5469] The value of the arlen and awlen ports on s_axi_rt don't correspond to a known AXI Protocol. Known lengths are 0, 4 and 8.
#WARNING: [IP_Flow 19-7070] Found addressable master interface 'm_axi_rt' without an associated address space. An addressable master interface must reference a valid address space within this IP for addressing to succeed. Please repackage this interface to provide the required address space information.
#WARNING: [IP_Flow 19-7071] Found addressable slave interface 's_axi_rt' without an associated memory map. An addressable slave interface must reference a valid memory map within this IP for addressing to succeed. Please repackage this interface to provide the required memory map information.
ipx::save_core [ipx::current_core]
create_ip -verbose -module_name $project -vlnv ethz.ch:user:axi_rt_unit_top_xilinx_ip

exit
