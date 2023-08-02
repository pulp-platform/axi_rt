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
    assign m_axi_``pat``_awvalid  [__i] = req[__i].aw_valid;               \
    assign m_axi_``pat``_awid     [__i] = req[__i].aw.id;                  \
    assign m_axi_``pat``_awaddr   [__i] = req[__i].aw.addr;                \
    assign m_axi_``pat``_awlen    [__i] = req[__i].aw.len;                 \
    assign m_axi_``pat``_awsize   [__i] = req[__i].aw.size;                \
    assign m_axi_``pat``_awburst  [__i] = req[__i].aw.burst;               \
    assign m_axi_``pat``_awlock   [__i] = req[__i].aw.lock;                \
    assign m_axi_``pat``_awcache  [__i] = req[__i].aw.cache;               \
    assign m_axi_``pat``_awprot   [__i] = req[__i].aw.prot;                \
    assign m_axi_``pat``_awqos    [__i] = req[__i].aw.qos;                 \
    assign m_axi_``pat``_awregion [__i] = req[__i].aw.region;              \
    assign m_axi_``pat``_awuser   [__i] = req[__i].aw.user;                \
                                                                           \
    assign m_axi_``pat``_wvalid   [__i] = req[__i].w_valid;                \
    assign m_axi_``pat``_wdata    [__i] = req[__i].w.data;                 \
    assign m_axi_``pat``_wstrb    [__i] = req[__i].w.strb;                 \
    assign m_axi_``pat``_wlast    [__i] = req[__i].w.last;                 \
    assign m_axi_``pat``_wuser    [__i] = req[__i].w.user;                 \
                                                                           \
    assign m_axi_``pat``_bready   [__i] = req[__i].b_ready;                \
                                                                           \
    assign m_axi_``pat``_arvalid  [__i] = req[__i].ar_valid;               \
    assign m_axi_``pat``_arid     [__i] = req[__i].ar.id;                  \
    assign m_axi_``pat``_araddr   [__i] = req[__i].ar.addr;                \
    assign m_axi_``pat``_arlen    [__i] = req[__i].ar.len;                 \
    assign m_axi_``pat``_arsize   [__i] = req[__i].ar.size;                \
    assign m_axi_``pat``_arburst  [__i] = req[__i].ar.burst;               \
    assign m_axi_``pat``_arlock   [__i] = req[__i].ar.lock;                \
    assign m_axi_``pat``_arcache  [__i] = req[__i].ar.cache;               \
    assign m_axi_``pat``_arprot   [__i] = req[__i].ar.prot;                \
    assign m_axi_``pat``_arqos    [__i] = req[__i].ar.qos;                 \
    assign m_axi_``pat``_arregion [__i] = req[__i].ar.region;              \
    assign m_axi_``pat``_aruser   [__i] = req[__i].ar.user;                \
                                                                           \
    assign m_axi_``pat``_rready   [__i] = req[__i].r_ready;                \
                                                                           \
    assign rsp[__i].aw_ready = m_axi_``pat``_awready [__i];                \
    assign rsp[__i].ar_ready = m_axi_``pat``_arready [__i];                \
    assign rsp[__i].w_ready  = m_axi_``pat``_wready  [__i];                \
                                                                           \
    assign rsp[__i].b_valid  = m_axi_``pat``_bvalid  [__i];                \
    assign rsp[__i].b.id     = m_axi_``pat``_bid     [__i];                \
    assign rsp[__i].b.resp   = m_axi_``pat``_bresp   [__i];                \
    assign rsp[__i].b.user   = m_axi_``pat``_buser   [__i];                \
                                                                           \
    assign rsp[__i].r_valid  = m_axi_``pat``_rvalid  [__i];                \
    assign rsp[__i].r.id     = m_axi_``pat``_rid     [__i];                \
    assign rsp[__i].r.data   = m_axi_``pat``_rdata   [__i];                \
    assign rsp[__i].r.resp   = m_axi_``pat``_rresp   [__i];                \
    assign rsp[__i].r.last   = m_axi_``pat``_rlast   [__i];                \
    assign rsp[__i].r.user   = m_axi_``pat``_ruser   [__i];                \
  end

`define AXI_ASSIGN_SLAVE_TO_FLAT_ARRAY(pat, __width, req, rsp)             \
  for (genvar __i = 0; __i < __width; __i++) begin : gen_array_connect_stf \
    assign req[__i].aw_valid  = s_axi_``pat``_awvalid  [__i];              \
    assign req[__i].aw.id     = s_axi_``pat``_awid     [__i];              \
    assign req[__i].aw.addr   = s_axi_``pat``_awaddr   [__i];              \
    assign req[__i].aw.len    = s_axi_``pat``_awlen    [__i];              \
    assign req[__i].aw.size   = s_axi_``pat``_awsize   [__i];              \
    assign req[__i].aw.burst  = s_axi_``pat``_awburst  [__i];              \
    assign req[__i].aw.lock   = s_axi_``pat``_awlock   [__i];              \
    assign req[__i].aw.cache  = s_axi_``pat``_awcache  [__i];              \
    assign req[__i].aw.prot   = s_axi_``pat``_awprot   [__i];              \
    assign req[__i].aw.qos    = s_axi_``pat``_awqos    [__i];              \
    assign req[__i].aw.region = s_axi_``pat``_awregion [__i];              \
    assign req[__i].aw.user   = s_axi_``pat``_awuser   [__i];              \
                                                                           \
    assign req[__i].w_valid   = s_axi_``pat``_wvalid   [__i];              \
    assign req[__i].w.data    = s_axi_``pat``_wdata    [__i];              \
    assign req[__i].w.strb    = s_axi_``pat``_wstrb    [__i];              \
    assign req[__i].w.last    = s_axi_``pat``_wlast    [__i];              \
    assign req[__i].w.user    = s_axi_``pat``_wuser    [__i];              \
                                                                           \
    assign req[__i].b_ready   = s_axi_``pat``_bready   [__i];              \
                                                                           \
    assign req[__i].ar_valid  = s_axi_``pat``_arvalid  [__i];              \
    assign req[__i].ar.id     = s_axi_``pat``_arid     [__i];              \
    assign req[__i].ar.addr   = s_axi_``pat``_araddr   [__i];              \
    assign req[__i].ar.len    = s_axi_``pat``_arlen    [__i];              \
    assign req[__i].ar.size   = s_axi_``pat``_arsize   [__i];              \
    assign req[__i].ar.burst  = s_axi_``pat``_arburst  [__i];              \
    assign req[__i].ar.lock   = s_axi_``pat``_arlock   [__i];              \
    assign req[__i].ar.cache  = s_axi_``pat``_arcache  [__i];              \
    assign req[__i].ar.prot   = s_axi_``pat``_arprot   [__i];              \
    assign req[__i].ar.qos    = s_axi_``pat``_arqos    [__i];              \
    assign req[__i].ar.region = s_axi_``pat``_arregion [__i];              \
    assign req[__i].ar.user   = s_axi_``pat``_aruser   [__i];              \
                                                                           \
    assign req[__i].r_ready   = s_axi_``pat``_rready   [__i];              \
                                                                           \
    assign s_axi_``pat``_awready [__i] = rsp[__i].aw_ready;                \
    assign s_axi_``pat``_arready [__i] = rsp[__i].ar_ready;                \
    assign s_axi_``pat``_wready  [__i] = rsp[__i].w_ready;                 \
                                                                           \
    assign s_axi_``pat``_bvalid  [__i] = rsp[__i].b_valid;                 \
    assign s_axi_``pat``_bid     [__i] = rsp[__i].b.id;                    \
    assign s_axi_``pat``_bresp   [__i] = rsp[__i].b.resp;                  \
    assign s_axi_``pat``_buser   [__i] = rsp[__i].b.user;                  \
                                                                           \
    assign s_axi_``pat``_rvalid  [__i] = rsp[__i].r_valid;                 \
    assign s_axi_``pat``_rid     [__i] = rsp[__i].r.id;                    \
    assign s_axi_``pat``_rdata   [__i] = rsp[__i].r.data;                  \
    assign s_axi_``pat``_rresp   [__i] = rsp[__i].r.resp;                  \
    assign s_axi_``pat``_rlast   [__i] = rsp[__i].r.last;                  \
    assign s_axi_``pat``_ruser   [__i] = rsp[__i].r.user;                  \
  end
////////////////////////////////////////////////////////////////////////////////////////////////////

`endif
