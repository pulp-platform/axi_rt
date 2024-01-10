// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Authors:
// - Thomas Benz <tbenz@iis.ee.ethz.ch>

// Macros to assign AXI RT Interfaces and Structs

`ifndef AXI_RT_ASSIGN_SVH_
`define AXI_RT_ASSIGN_SVH_

////////////////////////////////////////////////////////////////////////////////////////////////////
// Macros instantiating highlighter
// `AXI_HIGHLIGHT(__name, __aw_t, __w_t, __b_t, __ar_t, __r_t, __req, __resp)
`define AXI_HIGHLIGHT(__name, __aw_t, __w_t, __b_t, __ar_t, __r_t, __req, __resp) \
  signal_highlighter #(                                                           \
    .T ( __aw_t )                                                                 \
  ) i_signal_highlighter_``__name``_aw (                                          \
    .ready_i ( __resp.aw_ready ),                                                 \
    .valid_i ( __req.aw_valid  ),                                                 \
    .data_i  ( __req.aw        )                                                  \
  );                                                                              \
  signal_highlighter #(                                                           \
    .T ( __w_t )                                                                  \
  ) i_signal_highlighter_``__name``_w (                                           \
    .ready_i ( __resp.w_ready ),                                                  \
    .valid_i ( __req.w_valid  ),                                                  \
    .data_i  ( __req.w        )                                                   \
  );                                                                              \
  signal_highlighter #(                                                           \
    .T ( __b_t )                                                                  \
  ) i_signal_highlighter_``__name``_b (                                           \
    .ready_i ( __req.b_ready  ),                                                  \
    .valid_i ( __resp.b_valid ),                                                  \
    .data_i  ( __resp.b       )                                                   \
  );                                                                              \
  signal_highlighter #(                                                           \
    .T ( __ar_t )                                                                 \
  ) i_signal_highlighter_``__name``_ar (                                          \
    .ready_i ( __resp.ar_ready ),                                                 \
    .valid_i ( __req.ar_valid  ),                                                 \
    .data_i  ( __req.ar        )                                                  \
  );                                                                              \
  signal_highlighter #(                                                           \
    .T ( __r_t )                                                                  \
  ) i_signal_highlighter_``__name``_r (                                           \
    .ready_i ( __req.r_ready  ),                                                  \
    .valid_i ( __resp.r_valid ),                                                  \
    .data_i  ( __resp.r       )                                                   \
  );
////////////////////////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////////////////////////
// Macros for assigning flattened AXI ports to req/resp AXI structs
// Flat AXI ports are required by the Vivado IP Integrator. Vivado naming convention is followed.
//
// Usage Example:
// `AXI_ASSIGN_MASTER_TO_FLAT_ARRAY("my_bus", __width, my_req_struct, my_rsp_struct)
`define AXI_ASSIGN_MASTER_TO_FLAT_ARRAY(pat, __width, req, rsp)            \
  for (genvar __i = 0; __i < __width; __i++) begin : gen_array_connect_mtf \
    assign m_axi_``pat``_awvalid_o  [__i] = req[__i].aw_valid;             \
    assign m_axi_``pat``_awid_o     [__i] = req[__i].aw.id;                \
    assign m_axi_``pat``_awaddr_o   [__i] = req[__i].aw.addr;              \
    assign m_axi_``pat``_awlen_o    [__i] = req[__i].aw.len;               \
    assign m_axi_``pat``_awsize_o   [__i] = req[__i].aw.size;              \
    assign m_axi_``pat``_awburst_o  [__i] = req[__i].aw.burst;             \
    assign m_axi_``pat``_awlock_o   [__i] = req[__i].aw.lock;              \
    assign m_axi_``pat``_awcache_o  [__i] = req[__i].aw.cache;             \
    assign m_axi_``pat``_awprot_o   [__i] = req[__i].aw.prot;              \
    assign m_axi_``pat``_awqos_o    [__i] = req[__i].aw.qos;               \
    assign m_axi_``pat``_awregion_o [__i] = req[__i].aw.region;            \
    assign m_axi_``pat``_awuser_o   [__i] = req[__i].aw.user;              \
                                                                           \
    assign m_axi_``pat``_wvalid_o   [__i] = req[__i].w_valid;              \
    assign m_axi_``pat``_wdata_o    [__i] = req[__i].w.data;               \
    assign m_axi_``pat``_wstrb_o    [__i] = req[__i].w.strb;               \
    assign m_axi_``pat``_wlast_o    [__i] = req[__i].w.last;               \
    assign m_axi_``pat``_wuser_o    [__i] = req[__i].w.user;               \
                                                                           \
    assign m_axi_``pat``_bready_o   [__i] = req[__i].b_ready;              \
                                                                           \
    assign m_axi_``pat``_arvalid_o  [__i] = req[__i].ar_valid;             \
    assign m_axi_``pat``_arid_o     [__i] = req[__i].ar.id;                \
    assign m_axi_``pat``_araddr_o   [__i] = req[__i].ar.addr;              \
    assign m_axi_``pat``_arlen_o    [__i] = req[__i].ar.len;               \
    assign m_axi_``pat``_arsize_o   [__i] = req[__i].ar.size;              \
    assign m_axi_``pat``_arburst_o  [__i] = req[__i].ar.burst;             \
    assign m_axi_``pat``_arlock_o   [__i] = req[__i].ar.lock;              \
    assign m_axi_``pat``_arcache_o  [__i] = req[__i].ar.cache;             \
    assign m_axi_``pat``_arprot_o   [__i] = req[__i].ar.prot;              \
    assign m_axi_``pat``_arqos_o    [__i] = req[__i].ar.qos;               \
    assign m_axi_``pat``_arregion_o [__i] = req[__i].ar.region;            \
    assign m_axi_``pat``_aruser_o   [__i] = req[__i].ar.user;              \
                                                                           \
    assign m_axi_``pat``_rready_o   [__i] = req[__i].r_ready;              \
                                                                           \
    assign rsp[__i].aw_ready = m_axi_``pat``_awready_i [__i];              \
    assign rsp[__i].ar_ready = m_axi_``pat``_arready_i [__i];              \
    assign rsp[__i].w_ready  = m_axi_``pat``_wready_i  [__i];              \
                                                                           \
    assign rsp[__i].b_valid  = m_axi_``pat``_bvalid_i  [__i];              \
    assign rsp[__i].b.id     = m_axi_``pat``_bid_i     [__i];              \
    assign rsp[__i].b.resp   = m_axi_``pat``_bresp_i   [__i];              \
    assign rsp[__i].b.user   = m_axi_``pat``_buser_i   [__i];              \
                                                                           \
    assign rsp[__i].r_valid  = m_axi_``pat``_rvalid_i  [__i];              \
    assign rsp[__i].r.id     = m_axi_``pat``_rid_i     [__i];              \
    assign rsp[__i].r.data   = m_axi_``pat``_rdata_i   [__i];              \
    assign rsp[__i].r.resp   = m_axi_``pat``_rresp_i   [__i];              \
    assign rsp[__i].r.last   = m_axi_``pat``_rlast_i   [__i];              \
    assign rsp[__i].r.user   = m_axi_``pat``_ruser_i   [__i];              \
  end

`define AXI_ASSIGN_SLAVE_TO_FLAT_ARRAY(pat, __width, req, rsp)             \
  for (genvar __i = 0; __i < __width; __i++) begin : gen_array_connect_stf \
    assign req[__i].aw_valid  = s_axi_``pat``_awvalid_i  [__i];            \
    assign req[__i].aw.id     = s_axi_``pat``_awid_i     [__i];            \
    assign req[__i].aw.addr   = s_axi_``pat``_awaddr_i   [__i];            \
    assign req[__i].aw.len    = s_axi_``pat``_awlen_i    [__i];            \
    assign req[__i].aw.size   = s_axi_``pat``_awsize_i   [__i];            \
    assign req[__i].aw.burst  = s_axi_``pat``_awburst_i  [__i];            \
    assign req[__i].aw.lock   = s_axi_``pat``_awlock_i   [__i];            \
    assign req[__i].aw.cache  = s_axi_``pat``_awcache_i  [__i];            \
    assign req[__i].aw.prot   = s_axi_``pat``_awprot_i   [__i];            \
    assign req[__i].aw.qos    = s_axi_``pat``_awqos_i    [__i];            \
    assign req[__i].aw.region = s_axi_``pat``_awregion_i [__i];            \
    assign req[__i].aw.user   = s_axi_``pat``_awuser_i   [__i];            \
                                                                           \
    assign req[__i].w_valid   = s_axi_``pat``_wvalid_i   [__i];            \
    assign req[__i].w.data    = s_axi_``pat``_wdata_i    [__i];            \
    assign req[__i].w.strb    = s_axi_``pat``_wstrb_i    [__i];            \
    assign req[__i].w.last    = s_axi_``pat``_wlast_i    [__i];            \
    assign req[__i].w.user    = s_axi_``pat``_wuser_i    [__i];            \
                                                                           \
    assign req[__i].b_ready   = s_axi_``pat``_bready_i   [__i];            \
                                                                           \
    assign req[__i].ar_valid  = s_axi_``pat``_arvalid_i  [__i];            \
    assign req[__i].ar.id     = s_axi_``pat``_arid_i     [__i];            \
    assign req[__i].ar.addr   = s_axi_``pat``_araddr_i   [__i];            \
    assign req[__i].ar.len    = s_axi_``pat``_arlen_i    [__i];            \
    assign req[__i].ar.size   = s_axi_``pat``_arsize_i   [__i];            \
    assign req[__i].ar.burst  = s_axi_``pat``_arburst_i  [__i];            \
    assign req[__i].ar.lock   = s_axi_``pat``_arlock_i   [__i];            \
    assign req[__i].ar.cache  = s_axi_``pat``_arcache_i  [__i];            \
    assign req[__i].ar.prot   = s_axi_``pat``_arprot_i   [__i];            \
    assign req[__i].ar.qos    = s_axi_``pat``_arqos_i    [__i];            \
    assign req[__i].ar.region = s_axi_``pat``_arregion_i [__i];            \
    assign req[__i].ar.user   = s_axi_``pat``_aruser_i   [__i];            \
                                                                           \
    assign req[__i].r_ready   = s_axi_``pat``_rready_i   [__i];            \
                                                                           \
    assign s_axi_``pat``_awready_o [__i] = rsp[__i].aw_ready;              \
    assign s_axi_``pat``_arready_o [__i] = rsp[__i].ar_ready;              \
    assign s_axi_``pat``_wready_o  [__i] = rsp[__i].w_ready;               \
                                                                           \
    assign s_axi_``pat``_bvalid_o  [__i] = rsp[__i].b_valid;               \
    assign s_axi_``pat``_bid_o     [__i] = rsp[__i].b.id;                  \
    assign s_axi_``pat``_bresp_o   [__i] = rsp[__i].b.resp;                \
    assign s_axi_``pat``_buser_o   [__i] = rsp[__i].b.user;                \
                                                                           \
    assign s_axi_``pat``_rvalid_o  [__i] = rsp[__i].r_valid;               \
    assign s_axi_``pat``_rid_o     [__i] = rsp[__i].r.id;                  \
    assign s_axi_``pat``_rdata_o   [__i] = rsp[__i].r.data;                \
    assign s_axi_``pat``_rresp_o   [__i] = rsp[__i].r.resp;                \
    assign s_axi_``pat``_rlast_o   [__i] = rsp[__i].r.last;                \
    assign s_axi_``pat``_ruser_o   [__i] = rsp[__i].r.user;                \
  end

////////////////////////////////////////////////////////////////////////////////////////////////////
// Macros for assigning flattened AXI Lite ports to req/resp AXI Lite structs
// Flat AXI Lite ports are required by the Vivado IP Integrator. Vivado naming
// convention is followed.
//
// Usage Example:
// `AXI_LITE_ASSIGN_MASTER_TO_FLAT_ARRAY("my_bus", __width, my_req_struct, my_rsp_struct)
`define AXI_LITE_ASSIGN_SLAVE_TO_FLAT_ARRAY(pat, __width, req, rsp) \
  assign req.aw_valid  = s_axi_lite_``pat``_awvalid_i  ;            \
  assign req.aw.addr   = s_axi_lite_``pat``_awaddr_i   ;            \
  assign req.aw.prot   = s_axi_lite_``pat``_awprot_i   ;            \
                                                                    \
  assign req.w_valid   = s_axi_lite_``pat``_wvalid_i   ;            \
  assign req.w.data    = s_axi_lite_``pat``_wdata_i    ;            \
  assign req.w.strb    = s_axi_lite_``pat``_wstrb_i    ;            \
                                                                    \
  assign req.b_ready   = s_axi_lite_``pat``_bready_i   ;            \
                                                                    \
  assign req.ar_valid  = s_axi_lite_``pat``_arvalid_i  ;            \
  assign req.ar.addr   = s_axi_lite_``pat``_araddr_i   ;            \
  assign req.ar.prot   = s_axi_lite_``pat``_arprot_i   ;            \
                                                                    \
  assign req.r_ready   = s_axi_lite_``pat``_rready_i   ;            \
                                                                    \
  assign s_axi_lite_``pat``_awready_o  = rsp.aw_ready;              \
  assign s_axi_lite_``pat``_arready_o  = rsp.ar_ready;              \
  assign s_axi_lite_``pat``_wready_o   = rsp.w_ready;               \
                                                                    \
  assign s_axi_lite_``pat``_bvalid_o   = rsp.b_valid;               \
  assign s_axi_lite_``pat``_bresp_o    = rsp.b.resp;                \
                                                                    \
  assign s_axi_lite_``pat``_rvalid_o   = rsp.r_valid;               \
  assign s_axi_lite_``pat``_rdata_o    = rsp.r.data;                \
  assign s_axi_lite_``pat``_rresp_o    = rsp.r.resp;
////////////////////////////////////////////////////////////////////////////////////////////////////
`endif
