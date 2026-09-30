// Copyright (c) 2014-2020 ETH Zurich, University of Bologna
// Modified for simple ID width conversion without gating logic
//
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

`include "common_cells/registers.svh"

/// Simple AXI ID Width Converter - bypasses all signals except ID conversion
///
/// This module only converts ID widths between slave and master ports.
/// All other signals are passed through directly without any gating or buffering.
/// Ready signals are NOT gated - they pass through combinationally.
///
/// This maintains ID independence by using a lookup table for remapping.
module tmu_id_remap #(
  /// ID width of the AXI4+ATOP slave port.
  parameter int unsigned AxiSlvPortIdWidth = 32'd0,
  /// Maximum number of different IDs that can be in flight at the slave port.
  parameter int unsigned AxiSlvPortMaxUniqIds = 32'd0,
  /// Maximum number of in-flight transactions with the same ID.
  parameter int unsigned AxiMaxTxnsPerId = 32'd0,
  /// ID width of the AXI4+ATOP master port.
  parameter int unsigned AxiMstPortIdWidth = 32'd0,
  /// Request struct type of the AXI4+ATOP slave port.
  parameter type slv_req_t = logic,
  /// Response struct type of the AXI4+ATOP slave port.
  parameter type slv_resp_t = logic,
  /// Request struct type of the AXI4+ATOP master port
  parameter type mst_req_t = logic,
  /// Response struct type of the AXI4+ATOP master port
  parameter type mst_resp_t = logic
) (
  /// Rising-edge clock of all ports
  input  logic      clk_i,
  /// Asynchronous reset, active low
  input  logic      rst_ni,
  /// Slave port request
  input  slv_req_t  slv_req_i,
  /// Slave port response
  output slv_resp_t slv_resp_o,
  /// Master port request
  output mst_req_t  mst_req_o,
  /// Master port response
  input  mst_resp_t mst_resp_i
);

  // ==========================================
  // Direct passthrough of all non-ID signals
  // ==========================================

  // AW channel (except ID and valid/ready which need ID conversion logic)
  assign mst_req_o.aw.addr   = slv_req_i.aw.addr;
  assign mst_req_o.aw.len    = slv_req_i.aw.len;
  assign mst_req_o.aw.size   = slv_req_i.aw.size;
  assign mst_req_o.aw.burst  = slv_req_i.aw.burst;
  assign mst_req_o.aw.lock   = slv_req_i.aw.lock;
  assign mst_req_o.aw.cache  = slv_req_i.aw.cache;
  assign mst_req_o.aw.prot   = slv_req_i.aw.prot;
  assign mst_req_o.aw.qos    = slv_req_i.aw.qos;
  assign mst_req_o.aw.region = slv_req_i.aw.region;
  assign mst_req_o.aw.atop   = slv_req_i.aw.atop;
  assign mst_req_o.aw.user   = slv_req_i.aw.user;

  // W channel - complete passthrough
  assign mst_req_o.w         = slv_req_i.w;
  assign mst_req_o.w_valid   = slv_req_i.w_valid;
  assign slv_resp_o.w_ready  = mst_resp_i.w_ready;

  // B channel (except ID)
  assign slv_resp_o.b.resp   = mst_resp_i.b.resp;
  assign slv_resp_o.b.user   = mst_resp_i.b.user;
  assign slv_resp_o.b_valid  = mst_resp_i.b_valid;
  assign mst_req_o.b_ready   = slv_req_i.b_ready;

  // AR channel (except ID and valid/ready which need ID conversion logic)
  assign mst_req_o.ar.addr   = slv_req_i.ar.addr;
  assign mst_req_o.ar.len    = slv_req_i.ar.len;
  assign mst_req_o.ar.size   = slv_req_i.ar.size;
  assign mst_req_o.ar.burst  = slv_req_i.ar.burst;
  assign mst_req_o.ar.lock   = slv_req_i.ar.lock;
  assign mst_req_o.ar.cache  = slv_req_i.ar.cache;
  assign mst_req_o.ar.prot   = slv_req_i.ar.prot;
  assign mst_req_o.ar.qos    = slv_req_i.ar.qos;
  assign mst_req_o.ar.region = slv_req_i.ar.region;
  assign mst_req_o.ar.user   = slv_req_i.ar.user;

  // R channel (except ID)
  assign slv_resp_o.r.data   = mst_resp_i.r.data;
  assign slv_resp_o.r.resp   = mst_resp_i.r.resp;
  assign slv_resp_o.r.last   = mst_resp_i.r.last;
  assign slv_resp_o.r.user   = mst_resp_i.r.user;
  assign slv_resp_o.r_valid  = mst_resp_i.r_valid;
  assign mst_req_o.r_ready   = slv_req_i.r_ready;

  // ==========================================
  // NO GATING: Direct passthrough of valid/ready
  // ==========================================
  assign mst_req_o.aw_valid  = slv_req_i.aw_valid;
  assign slv_resp_o.aw_ready = mst_resp_i.aw_ready;

  assign mst_req_o.ar_valid  = slv_req_i.ar_valid;
  assign slv_resp_o.ar_ready = mst_resp_i.ar_ready;

  // ==========================================
  // ID Remapping Tables and Logic
  // ==========================================

  localparam int unsigned IdxWidth = cf_math_pkg::idx_width(AxiSlvPortMaxUniqIds);
  typedef logic [AxiSlvPortMaxUniqIds-1:0]  field_t;
  typedef logic [AxiSlvPortIdWidth-1:0]     id_inp_t;
  typedef logic [IdxWidth-1:0]              idx_t;

  field_t   wr_free,          rd_free;
  idx_t     wr_free_oup_id,   rd_free_oup_id,
            wr_push_oup_id,   rd_push_oup_id,
            wr_exists_id,     rd_exists_id;
  logic     wr_exists,        rd_exists,
            wr_exists_full,   rd_exists_full,
            wr_full,          rd_full;

  // Write channel ID remap table
  axi_id_remap_table #(
    .InpIdWidth     ( AxiSlvPortIdWidth     ),
    .MaxUniqInpIds  ( AxiSlvPortMaxUniqIds  ),
    .MaxTxnsPerId   ( AxiMaxTxnsPerId       )
  ) i_wr_table (
    .clk_i,
    .rst_ni,
    .free_o          ( wr_free                                 ),
    .free_oup_id_o   ( wr_free_oup_id                          ),
    .full_o          ( wr_full                                 ),
    .push_i          ( slv_req_i.aw_valid && mst_resp_i.aw_ready ),
    .push_inp_id_i   ( slv_req_i.aw.id                         ),
    .push_oup_id_i   ( wr_push_oup_id                          ),
    .exists_inp_id_i ( slv_req_i.aw.id                         ),
    .exists_o        ( wr_exists                               ),
    .exists_oup_id_o ( wr_exists_id                            ),
    .exists_full_o   ( wr_exists_full                          ),
    .pop_i           ( slv_resp_o.b_valid && slv_req_i.b_ready ),
    .pop_oup_id_i    ( mst_resp_i.b.id[IdxWidth-1:0]           ),
    .pop_inp_id_o    ( slv_resp_o.b.id                         )
  );

  // Read channel ID remap table
  axi_id_remap_table #(
    .InpIdWidth     ( AxiSlvPortIdWidth     ),
    .MaxUniqInpIds  ( AxiSlvPortMaxUniqIds  ),
    .MaxTxnsPerId   ( AxiMaxTxnsPerId       )
  ) i_rd_table (
    .clk_i,
    .rst_ni,
    .free_o           ( rd_free                                                      ),
    .free_oup_id_o    ( rd_free_oup_id                                               ),
    .full_o           ( rd_full                                                      ),
    .push_i           ( slv_req_i.ar_valid && mst_resp_i.ar_ready                    ),
    .push_inp_id_i    ( slv_req_i.ar.id                                              ),
    .push_oup_id_i    ( rd_push_oup_id                                               ),
    .exists_inp_id_i  ( slv_req_i.ar.id                                              ),
    .exists_o         ( rd_exists                                                    ),
    .exists_oup_id_o  ( rd_exists_id                                                 ),
    .exists_full_o    ( rd_exists_full                                               ),
    .pop_i            ( slv_resp_o.r_valid && slv_req_i.r_ready && slv_resp_o.r.last ),
    .pop_oup_id_i     ( mst_resp_i.r.id[IdxWidth-1:0]                                ),
    .pop_inp_id_o     ( slv_resp_o.r.id                                              )
  );

  // ==========================================
  // ID Conversion Logic (Combinational)
  // ==========================================

  // For AW channel: use existing ID if found, otherwise use next free ID
  always_comb begin
    if (wr_exists) begin
      wr_push_oup_id = wr_exists_id;
    end else begin
      wr_push_oup_id = wr_free_oup_id;
    end
  end

  // For AR channel: use existing ID if found, otherwise use next free ID
  always_comb begin
    if (rd_exists) begin
      rd_push_oup_id = rd_exists_id;
    end else begin
      rd_push_oup_id = rd_free_oup_id;
    end
  end

  // Zero-extend output IDs if master port IDs are wider than table indices
  localparam ZeroWidth = AxiMstPortIdWidth - IdxWidth;
  assign mst_req_o.ar.id = {{ZeroWidth{1'b0}}, rd_push_oup_id};
  assign mst_req_o.aw.id = {{ZeroWidth{1'b0}}, wr_push_oup_id};

  // ==========================================
  // Assertions
  // ==========================================

  // pragma translate_off
  `ifndef VERILATOR
  initial begin : p_assert
    assert(AxiSlvPortIdWidth > 32'd0)
      else $fatal(1, "Parameter AxiSlvPortIdWidth has to be larger than 0!");
    assert(AxiMstPortIdWidth >= IdxWidth)
      else $fatal(1, "Parameter AxiMstPortIdWidth has to be at least IdxWidth!");
    assert (AxiSlvPortMaxUniqIds > 0)
      else $fatal(1, "Parameter AxiSlvPortMaxUniqIds has to be larger than 0!");
    assert (AxiSlvPortMaxUniqIds <= 2**AxiSlvPortIdWidth)
      else $fatal(1, "Parameter AxiSlvPortMaxUniqIds may be at most 2**AxiSlvPortIdWidth!");
    assert (AxiMaxTxnsPerId > 0)
      else $fatal(1, "Parameter AxiMaxTxnsPerId has to be larger than 0!");
    assert($bits(slv_req_i.aw.addr) == $bits(mst_req_o.aw.addr))
      else $fatal(1, "AXI AW address widths are not equal!");
    assert($bits(slv_req_i.w.data) == $bits(mst_req_o.w.data))
      else $fatal(1, "AXI W data widths are not equal!");
    assert($bits(slv_req_i.w.user) == $bits(mst_req_o.w.user))
      else $fatal(1, "AXI W user widths are not equal!");
    assert($bits(slv_req_i.ar.addr) == $bits(mst_req_o.ar.addr))
      else $fatal(1, "AXI AR address widths are not equal!");
    assert($bits(slv_resp_o.r.data) == $bits(mst_resp_i.r.data))
      else $fatal(1, "AXI R data widths are not equal!");
    assert ($bits(slv_req_i.aw.id) == AxiSlvPortIdWidth);
    assert ($bits(slv_resp_o.b.id) == AxiSlvPortIdWidth);
    assert ($bits(slv_req_i.ar.id) == AxiSlvPortIdWidth);
    assert ($bits(slv_resp_o.r.id) == AxiSlvPortIdWidth);
    assert ($bits(mst_req_o.aw.id) == AxiMstPortIdWidth);
    assert ($bits(mst_resp_i.b.id) == AxiMstPortIdWidth);
    assert ($bits(mst_req_o.ar.id) == AxiMstPortIdWidth);
    assert ($bits(mst_resp_i.r.id) == AxiMstPortIdWidth);
  end

  // Verify no gating occurs
  default disable iff (!rst_ni);
  assert property (@(posedge clk_i) slv_req_i.aw_valid |-> mst_req_o.aw_valid)
    else $error("AW valid should pass through!");
  assert property (@(posedge clk_i) mst_resp_i.aw_ready |-> slv_resp_o.aw_ready)
    else $error("AW ready should pass through!");
  assert property (@(posedge clk_i) slv_req_i.ar_valid |-> mst_req_o.ar_valid)
    else $error("AR valid should pass through!");
  assert property (@(posedge clk_i) mst_resp_i.ar_ready |-> slv_resp_o.ar_ready)
    else $error("AR ready should pass through!");
  `endif
  // pragma translate_on

endmodule