// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Authors:
// - Thomas Benz <tbenz@iis.ee.ethz.ch>

// Macros to add AXI ports

`ifndef AXI_RT_PORT_SVH_
`define AXI_RT_PORT_SVH_

////////////////////////////////////////////////////////////////////////////////////////////////////
// Macros creating flat AXI ports
// `AXI_M_PORT_ARRAY(__name, __width, __addr_t, __data_t, __strb_t, __id_t, __aw_user_t, __w_user_t, __b_user_t, __ar_user_t, __r_user_t)
`define AXI_M_PORT_ARRAY(__name, __width, __addr_t, __data_t, __strb_t, __id_t, __aw_user_t, __w_user_t, __b_user_t, __ar_user_t, __r_user_t) \
  output logic             [__width-1:0] m_axi_``__name``_awvalid_o,   \
  output __id_t            [__width-1:0] m_axi_``__name``_awid_o,      \
  output __addr_t          [__width-1:0] m_axi_``__name``_awaddr_o,    \
  output axi_pkg::len_t    [__width-1:0] m_axi_``__name``_awlen_o,     \
  output axi_pkg::size_t   [__width-1:0] m_axi_``__name``_awsize_o,    \
  output axi_pkg::burst_t  [__width-1:0] m_axi_``__name``_awburst_o,   \
  output logic             [__width-1:0] m_axi_``__name``_awlock_o,    \
  output axi_pkg::cache_t  [__width-1:0] m_axi_``__name``_awcache_o,   \
  output axi_pkg::prot_t   [__width-1:0] m_axi_``__name``_awprot_o,    \
  output axi_pkg::qos_t    [__width-1:0] m_axi_``__name``_awqos_o,     \
  output axi_pkg::region_t [__width-1:0] m_axi_``__name``_awregion_o,  \
  output __aw_user_t       [__width-1:0] m_axi_``__name``_awuser_o,    \
  output logic             [__width-1:0] m_axi_``__name``_wvalid_o,    \
  output __data_t          [__width-1:0] m_axi_``__name``_wdata_o,     \
  output __strb_t          [__width-1:0] m_axi_``__name``_wstrb_o,     \
  output logic             [__width-1:0] m_axi_``__name``_wlast_o,     \
  output __w_user_t        [__width-1:0] m_axi_``__name``_wuser_o,     \
  output logic             [__width-1:0] m_axi_``__name``_bready_o,    \
  output logic             [__width-1:0] m_axi_``__name``_arvalid_o,   \
  output __id_t            [__width-1:0] m_axi_``__name``_arid_o,      \
  output __addr_t          [__width-1:0] m_axi_``__name``_araddr_o,    \
  output axi_pkg::len_t    [__width-1:0] m_axi_``__name``_arlen_o,     \
  output axi_pkg::size_t   [__width-1:0] m_axi_``__name``_arsize_o,    \
  output axi_pkg::burst_t  [__width-1:0] m_axi_``__name``_arburst_o,   \
  output logic             [__width-1:0] m_axi_``__name``_arlock_o,    \
  output axi_pkg::cache_t  [__width-1:0] m_axi_``__name``_arcache_o,   \
  output axi_pkg::prot_t   [__width-1:0] m_axi_``__name``_arprot_o,    \
  output axi_pkg::qos_t    [__width-1:0] m_axi_``__name``_arqos_o,     \
  output axi_pkg::region_t [__width-1:0] m_axi_``__name``_arregion_o,  \
  output __ar_user_t       [__width-1:0] m_axi_``__name``_aruser_o,    \
  output logic             [__width-1:0] m_axi_``__name``_rready_o,    \
  input  logic             [__width-1:0] m_axi_``__name``_awready_i,   \
  input  logic             [__width-1:0] m_axi_``__name``_arready_i,   \
  input  logic             [__width-1:0] m_axi_``__name``_wready_i,    \
  input  logic             [__width-1:0] m_axi_``__name``_bvalid_i,    \
  input  __id_t            [__width-1:0] m_axi_``__name``_bid_i,       \
  input  axi_pkg::resp_t   [__width-1:0] m_axi_``__name``_bresp_i,     \
  input  __b_user_t        [__width-1:0] m_axi_``__name``_buser_i,     \
  input  logic             [__width-1:0] m_axi_``__name``_rvalid_i,    \
  input  __id_t            [__width-1:0] m_axi_``__name``_rid_i,       \
  input  __data_t          [__width-1:0] m_axi_``__name``_rdata_i,     \
  input  axi_pkg::resp_t   [__width-1:0] m_axi_``__name``_rresp_i,     \
  input  logic             [__width-1:0] m_axi_``__name``_rlast_i,     \
  input  __r_user_t        [__width-1:0] m_axi_``__name``_ruser_i,     \
////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////
// Macros creating flat AXI ports
// `AXI_S_PORT_ARRAY(__name, __width, __addr_t, __data_t, __strb_t, __id_t, __aw_user_t, __w_user_t, __b_user_t, __ar_user_t, __r_user_t)
`define AXI_S_PORT_ARRAY(__name, __width, __addr_t, __data_t, __strb_t, __id_t, __aw_user_t, __w_user_t, __b_user_t, __ar_user_t, __r_user_t) \
  input  logic             [__width-1:0] s_axi_``__name``_awvalid_i,   \
  input  __id_t            [__width-1:0] s_axi_``__name``_awid_i,      \
  input  __addr_t          [__width-1:0] s_axi_``__name``_awaddr_i,    \
  input  axi_pkg::len_t    [__width-1:0] s_axi_``__name``_awlen_i,     \
  input  axi_pkg::size_t   [__width-1:0] s_axi_``__name``_awsize_i,    \
  input  axi_pkg::burst_t  [__width-1:0] s_axi_``__name``_awburst_i,   \
  input  logic             [__width-1:0] s_axi_``__name``_awlock_i,    \
  input  axi_pkg::cache_t  [__width-1:0] s_axi_``__name``_awcache_i,   \
  input  axi_pkg::prot_t   [__width-1:0] s_axi_``__name``_awprot_i,    \
  input  axi_pkg::qos_t    [__width-1:0] s_axi_``__name``_awqos_i,     \
  input  axi_pkg::region_t [__width-1:0] s_axi_``__name``_awregion_i,  \
  input  __aw_user_t       [__width-1:0] s_axi_``__name``_awuser_i,    \
  input  logic             [__width-1:0] s_axi_``__name``_wvalid_i,    \
  input  __data_t          [__width-1:0] s_axi_``__name``_wdata_i,     \
  input  __strb_t          [__width-1:0] s_axi_``__name``_wstrb_i,     \
  input  logic             [__width-1:0] s_axi_``__name``_wlast_i,     \
  input  __w_user_t        [__width-1:0] s_axi_``__name``_wuser_i,     \
  input  logic             [__width-1:0] s_axi_``__name``_bready_i,    \
  input  logic             [__width-1:0] s_axi_``__name``_arvalid_i,   \
  input  __id_t            [__width-1:0] s_axi_``__name``_arid_i,      \
  input  __addr_t          [__width-1:0] s_axi_``__name``_araddr_i,    \
  input  axi_pkg::len_t    [__width-1:0] s_axi_``__name``_arlen_i,     \
  input  axi_pkg::size_t   [__width-1:0] s_axi_``__name``_arsize_i,    \
  input  axi_pkg::burst_t  [__width-1:0] s_axi_``__name``_arburst_i,   \
  input  logic             [__width-1:0] s_axi_``__name``_arlock_i,    \
  input  axi_pkg::cache_t  [__width-1:0] s_axi_``__name``_arcache_i,   \
  input  axi_pkg::prot_t   [__width-1:0] s_axi_``__name``_arprot_i,    \
  input  axi_pkg::qos_t    [__width-1:0] s_axi_``__name``_arqos_i,     \
  input  axi_pkg::region_t [__width-1:0] s_axi_``__name``_arregion_i,  \
  input  __ar_user_t       [__width-1:0] s_axi_``__name``_aruser_i,    \
  input  logic             [__width-1:0] s_axi_``__name``_rready_i,    \
  output logic             [__width-1:0] s_axi_``__name``_awready_o,   \
  output logic             [__width-1:0] s_axi_``__name``_arready_o,   \
  output logic             [__width-1:0] s_axi_``__name``_wready_o,    \
  output logic             [__width-1:0] s_axi_``__name``_bvalid_o,    \
  output __id_t            [__width-1:0] s_axi_``__name``_bid_o,       \
  output axi_pkg::resp_t   [__width-1:0] s_axi_``__name``_bresp_o,     \
  output __b_user_t        [__width-1:0] s_axi_``__name``_buser_o,     \
  output logic             [__width-1:0] s_axi_``__name``_rvalid_o,    \
  output __id_t            [__width-1:0] s_axi_``__name``_rid_o,       \
  output __data_t          [__width-1:0] s_axi_``__name``_rdata_o,     \
  output axi_pkg::resp_t   [__width-1:0] s_axi_``__name``_rresp_o,     \
  output logic             [__width-1:0] s_axi_``__name``_rlast_o,     \
  output __r_user_t        [__width-1:0] s_axi_``__name``_ruser_o,     \
////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////
// Macros creating flat AXI-Lite ports
// `AXI_LITE_M_PORT_ARRAY(__name, __width, __addr_t, __data_t, __strb_t)
`define AXI_LITE_M_PORT_ARRAY(__name, __width, __addr_t, __data_t, __strb_t) \
  output logic             [__width-1:0] m_axi_lite_``__name``_awvalid_o,   \
  output __addr_t          [__width-1:0] m_axi_lite_``__name``_awaddr_o,    \
  output axi_pkg::prot_t   [__width-1:0] m_axi_lite_``__name``_awprot_o,    \
  output logic             [__width-1:0] m_axi_lite_``__name``_wvalid_o,    \
  output __data_t          [__width-1:0] m_axi_lite_``__name``_wdata_o,     \
  output __strb_t          [__width-1:0] m_axi_lite_``__name``_wstrb_o,     \
  output logic             [__width-1:0] m_axi_lite_``__name``_bready_o,    \
  output logic             [__width-1:0] m_axi_lite_``__name``_arvalid_o,   \
  output __addr_t          [__width-1:0] m_axi_lite_``__name``_araddr_o,    \
  output axi_pkg::prot_t   [__width-1:0] m_axi_lite_``__name``_arprot_o,    \
  output logic             [__width-1:0] m_axi_lite_``__name``_rready_o,    \
  input  logic             [__width-1:0] m_axi_lite_``__name``_awready_i,   \
  input  logic             [__width-1:0] m_axi_lite_``__name``_arready_i,   \
  input  logic             [__width-1:0] m_axi_lite_``__name``_wready_i,    \
  input  logic             [__width-1:0] m_axi_lite_``__name``_bvalid_o,    \
  input  axi_pkg::resp_t   [__width-1:0] m_axi_lite_``__name``_bresp_i,     \
  input  logic             [__width-1:0] m_axi_lite_``__name``_rvalid_o,    \
  input  __data_t          [__width-1:0] m_axi_lite_``__name``_rdata_i,     \
  input  axi_pkg::resp_t   [__width-1:0] m_axi_lite_``__name``_rresp_i,     \
////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////
// Macros creating flat AXI-Lite ports
// `AXI_LITE_S_PORT_ARRAY(__name, __width, __addr_t, __data_t, __strb_t)
`define AXI_LITE_S_PORT_ARRAY(__name, __width, __addr_t, __data_t, __strb_t) \
  input  logic             [__width-1:0] s_axi_lite_``__name``_awvalid_i,   \
  input  __addr_t          [__width-1:0] s_axi_lite_``__name``_awaddr_i,    \
  input  axi_pkg::prot_t   [__width-1:0] s_axi_lite_``__name``_awprot_i,    \
  input  logic             [__width-1:0] s_axi_lite_``__name``_wvalid_i,    \
  input  __data_t          [__width-1:0] s_axi_lite_``__name``_wdata_i,     \
  input  __strb_t          [__width-1:0] s_axi_lite_``__name``_wstrb_i,     \
  input  logic             [__width-1:0] s_axi_lite_``__name``_bready_i,    \
  input  logic             [__width-1:0] s_axi_lite_``__name``_arvalid_i,   \
  input  __addr_t          [__width-1:0] s_axi_lite_``__name``_araddr_i,    \
  input  axi_pkg::prot_t   [__width-1:0] s_axi_lite_``__name``_arprot_i,    \
  input  logic             [__width-1:0] s_axi_lite_``__name``_rready_i,    \
  output logic             [__width-1:0] s_axi_lite_``__name``_awready_o,   \
  output logic             [__width-1:0] s_axi_lite_``__name``_arready_o,   \
  output logic             [__width-1:0] s_axi_lite_``__name``_wready_o,    \
  output logic             [__width-1:0] s_axi_lite_``__name``_bvalid_i,    \
  output axi_pkg::resp_t   [__width-1:0] s_axi_lite_``__name``_bresp_o,     \
  output logic             [__width-1:0] s_axi_lite_``__name``_rvalid_i,    \
  output __data_t          [__width-1:0] s_axi_lite_``__name``_rdata_o,     \
  output axi_pkg::resp_t   [__width-1:0] s_axi_lite_``__name``_rresp_o,     \
////////////////////////////////////////////////////////////////////////////////////////////////////

`endif
