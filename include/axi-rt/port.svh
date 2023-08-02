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
  output logic             [__width-1:0] m_axi_``__name``_awvalid,   \
  output __id_t            [__width-1:0] m_axi_``__name``_awid,      \
  output __addr_t          [__width-1:0] m_axi_``__name``_awaddr,    \
  output axi_pkg::len_t    [__width-1:0] m_axi_``__name``_awlen,     \
  output axi_pkg::size_t   [__width-1:0] m_axi_``__name``_awsize,    \
  output axi_pkg::burst_t  [__width-1:0] m_axi_``__name``_awburst,   \
  output logic             [__width-1:0] m_axi_``__name``_awlock,    \
  output axi_pkg::cache_t  [__width-1:0] m_axi_``__name``_awcache,   \
  output axi_pkg::prot_t   [__width-1:0] m_axi_``__name``_awprot,    \
  output axi_pkg::qos_t    [__width-1:0] m_axi_``__name``_awqos,     \
  output axi_pkg::region_t [__width-1:0] m_axi_``__name``_awregion,  \
  output __aw_user_t       [__width-1:0] m_axi_``__name``_awuser,    \
  output logic             [__width-1:0] m_axi_``__name``_wvalid,    \
  output __data_t          [__width-1:0] m_axi_``__name``_wdata,     \
  output __strb_t          [__width-1:0] m_axi_``__name``_wstrb,     \
  output logic             [__width-1:0] m_axi_``__name``_wlast,     \
  output __w_user_t        [__width-1:0] m_axi_``__name``_wuser,     \
  output logic             [__width-1:0] m_axi_``__name``_bready,    \
  output logic             [__width-1:0] m_axi_``__name``_arvalid,   \
  output __id_t            [__width-1:0] m_axi_``__name``_arid,      \
  output __addr_t          [__width-1:0] m_axi_``__name``_araddr,    \
  output axi_pkg::len_t    [__width-1:0] m_axi_``__name``_arlen,     \
  output axi_pkg::size_t   [__width-1:0] m_axi_``__name``_arsize,    \
  output axi_pkg::burst_t  [__width-1:0] m_axi_``__name``_arburst,   \
  output logic             [__width-1:0] m_axi_``__name``_arlock,    \
  output axi_pkg::cache_t  [__width-1:0] m_axi_``__name``_arcache,   \
  output axi_pkg::prot_t   [__width-1:0] m_axi_``__name``_arprot,    \
  output axi_pkg::qos_t    [__width-1:0] m_axi_``__name``_arqos,     \
  output axi_pkg::region_t [__width-1:0] m_axi_``__name``_arregion,  \
  output __ar_user_t       [__width-1:0] m_axi_``__name``_aruser,    \
  output logic             [__width-1:0] m_axi_``__name``_rready,    \
  input  logic             [__width-1:0] m_axi_``__name``_awready,   \
  input  logic             [__width-1:0] m_axi_``__name``_arready,   \
  input  logic             [__width-1:0] m_axi_``__name``_wready,    \
  input  logic             [__width-1:0] m_axi_``__name``_bvalid,    \
  input  __id_t            [__width-1:0] m_axi_``__name``_bid,       \
  input  axi_pkg::resp_t   [__width-1:0] m_axi_``__name``_bresp,     \
  input  __b_user_t        [__width-1:0] m_axi_``__name``_buser,     \
  input  logic             [__width-1:0] m_axi_``__name``_rvalid,    \
  input  __id_t            [__width-1:0] m_axi_``__name``_rid,       \
  input  __data_t          [__width-1:0] m_axi_``__name``_rdata,     \
  input  axi_pkg::resp_t   [__width-1:0] m_axi_``__name``_rresp,     \
  input  logic             [__width-1:0] m_axi_``__name``_rlast,     \
  input  __r_user_t        [__width-1:0] m_axi_``__name``_ruser,     \
////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////
// Macros creating flat AXI ports
// `AXI_S_PORT_ARRAY(__name, __width, __addr_t, __data_t, __strb_t, __id_t, __aw_user_t, __w_user_t, __b_user_t, __ar_user_t, __r_user_t)
`define AXI_S_PORT_ARRAY(__name, __width, __addr_t, __data_t, __strb_t, __id_t, __aw_user_t, __w_user_t, __b_user_t, __ar_user_t, __r_user_t) \
  input  logic             [__width-1:0] s_axi_``__name``_awvalid,   \
  input  __id_t            [__width-1:0] s_axi_``__name``_awid,      \
  input  __addr_t          [__width-1:0] s_axi_``__name``_awaddr,    \
  input  axi_pkg::len_t    [__width-1:0] s_axi_``__name``_awlen,     \
  input  axi_pkg::size_t   [__width-1:0] s_axi_``__name``_awsize,    \
  input  axi_pkg::burst_t  [__width-1:0] s_axi_``__name``_awburst,   \
  input  logic             [__width-1:0] s_axi_``__name``_awlock,    \
  input  axi_pkg::cache_t  [__width-1:0] s_axi_``__name``_awcache,   \
  input  axi_pkg::prot_t   [__width-1:0] s_axi_``__name``_awprot,    \
  input  axi_pkg::qos_t    [__width-1:0] s_axi_``__name``_awqos,     \
  input  axi_pkg::region_t [__width-1:0] s_axi_``__name``_awregion,  \
  input  __aw_user_t       [__width-1:0] s_axi_``__name``_awuser,    \
  input  logic             [__width-1:0] s_axi_``__name``_wvalid,    \
  input  __data_t          [__width-1:0] s_axi_``__name``_wdata,     \
  input  __strb_t          [__width-1:0] s_axi_``__name``_wstrb,     \
  input  logic             [__width-1:0] s_axi_``__name``_wlast,     \
  input  __w_user_t        [__width-1:0] s_axi_``__name``_wuser,     \
  input  logic             [__width-1:0] s_axi_``__name``_bready,    \
  input  logic             [__width-1:0] s_axi_``__name``_arvalid,   \
  input  __id_t            [__width-1:0] s_axi_``__name``_arid,      \
  input  __addr_t          [__width-1:0] s_axi_``__name``_araddr,    \
  input  axi_pkg::len_t    [__width-1:0] s_axi_``__name``_arlen,     \
  input  axi_pkg::size_t   [__width-1:0] s_axi_``__name``_arsize,    \
  input  axi_pkg::burst_t  [__width-1:0] s_axi_``__name``_arburst,   \
  input  logic             [__width-1:0] s_axi_``__name``_arlock,    \
  input  axi_pkg::cache_t  [__width-1:0] s_axi_``__name``_arcache,   \
  input  axi_pkg::prot_t   [__width-1:0] s_axi_``__name``_arprot,    \
  input  axi_pkg::qos_t    [__width-1:0] s_axi_``__name``_arqos,     \
  input  axi_pkg::region_t [__width-1:0] s_axi_``__name``_arregion,  \
  input  __ar_user_t       [__width-1:0] s_axi_``__name``_aruser,    \
  input  logic             [__width-1:0] s_axi_``__name``_rready,    \
  output logic             [__width-1:0] s_axi_``__name``_awready,   \
  output logic             [__width-1:0] s_axi_``__name``_arready,   \
  output logic             [__width-1:0] s_axi_``__name``_wready,    \
  output logic             [__width-1:0] s_axi_``__name``_bvalid,    \
  output __id_t            [__width-1:0] s_axi_``__name``_bid,       \
  output axi_pkg::resp_t   [__width-1:0] s_axi_``__name``_bresp,     \
  output __b_user_t        [__width-1:0] s_axi_``__name``_buser,     \
  output logic             [__width-1:0] s_axi_``__name``_rvalid,    \
  output __id_t            [__width-1:0] s_axi_``__name``_rid,       \
  output __data_t          [__width-1:0] s_axi_``__name``_rdata,     \
  output axi_pkg::resp_t   [__width-1:0] s_axi_``__name``_rresp,     \
  output logic             [__width-1:0] s_axi_``__name``_rlast,     \
  output __r_user_t        [__width-1:0] s_axi_``__name``_ruser,     \
////////////////////////////////////////////////////////////////////////////////////////////////////

`endif
