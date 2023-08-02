// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Wolfgang Roenninger <wroennin@iis.ee.ethz.ch>
// - Andreas Kurth <akurth@iis.ee.ethz.ch>
// - Thomas Benz <tbenz@iis.ee.ethz.ch>

`include "axi/typedef.svh"
`include "common_cells/registers.svh"

/// Split AXI4 bursts into single-beat transactions.
///
/// ## Limitations
///
/// - This module does not support wrapping ([`axi_pkg::BURST_WRAP`](package.axi_pkg)) bursts and
///   responds to such bursts with slave error(s).
/// - This module does not support atomic operations (ATOPs) and responds to ATOPs with a slave
///   error.  Place an [`axi_atop_filter`](module.axi_atop_filter) before this module if upstream
///   modules can generate ATOPs.
module axi_gran_burst_splitter #(
  // Maximum number of AXI read bursts outstanding at the same time
  parameter int unsigned MaxReadTxns   = 32'd0,
  // Maximum number of AXI write bursts outstanding at the same time
  parameter int unsigned MaxWriteTxns  = 32'd0,
  parameter bit          CutPath       = 1'b0,
  // AXI Bus Types
  parameter int unsigned AddrWidth     = 32'd0,
  parameter int unsigned DataWidth     = 32'd0,
  parameter int unsigned IdWidth       = 32'd0,
  parameter int unsigned UserWidth     = 32'd0,
  parameter type         axi_req_t     = logic,
  parameter type         axi_resp_t    = logic,
  parameter type         axi_aw_chan_t = logic,
  parameter type         axi_w_chan_t  = logic,
  parameter type         axi_b_chan_t  = logic,
  parameter type         axi_ar_chan_t = logic,
  parameter type         axi_r_chan_t  = logic
) (
  input  logic  clk_i,
  input  logic  rst_ni,

  // length
  input  axi_pkg::len_t len_limit_i,

  // Input / Slave Port
  input  axi_req_t  slv_req_i,
  output axi_resp_t slv_resp_o,

  // Output / Master Port
  output axi_req_t  mst_req_o,
  input  axi_resp_t mst_resp_i
);

  // Demultiplex between supported and unsupported transactions.
  axi_req_t   slv_req,  act_req,  unsupported_req;
  axi_resp_t  slv_resp, act_resp, unsupported_resp;

  axi_multicut #(
    .NoCuts    ( CutPath  ),
    .aw_chan_t ( axi_aw_chan_t ),
    .w_chan_t  ( axi_w_chan_t  ),
    .b_chan_t  ( axi_b_chan_t  ),
    .ar_chan_t ( axi_ar_chan_t ),
    .r_chan_t  ( axi_r_chan_t  ),
    .axi_req_t ( axi_req_t     ),
    .axi_resp_t( axi_resp_t    )
  ) i_axi_multicut (
    .clk_i,
    .rst_ni,
    .slv_req_i ,
    .slv_resp_o,
    .mst_req_o   ( slv_req  ),
    .mst_resp_i  ( slv_resp )
  );

  logic sel_aw_unsupported, sel_ar_unsupported;
  localparam int unsigned MaxTxns = (MaxReadTxns > MaxWriteTxns) ? MaxReadTxns : MaxWriteTxns;
  axi_demux_simple #(
    .AxiIdWidth   ( IdWidth     ),
    .axi_req_t    ( axi_req_t   ),
    .axi_resp_t   ( axi_resp_t  ),
    .NoMstPorts   ( 2           ),
    .MaxTrans     ( MaxTxns     ),
    .AxiLookBits  ( IdWidth     )
  ) i_demux_supported_vs_unsupported (
    .clk_i,
    .rst_ni,
    .test_i           ( 1'b0                          ),
    .slv_req_i        ( slv_req ),
    .slv_aw_select_i  ( sel_aw_unsupported            ),
    .slv_ar_select_i  ( sel_ar_unsupported            ),
    .slv_resp_o       ( slv_resp ),
    .mst_reqs_o       ( {unsupported_req,  act_req}   ),
    .mst_resps_i      ( {unsupported_resp, act_resp}  )
  );
  // Define supported transactions.
  function bit txn_supported(axi_pkg::atop_t atop, axi_pkg::burst_t burst, axi_pkg::cache_t cache,
      axi_pkg::len_t len);
    // Single-beat transactions do not need splitting, so all are supported.
    if (len == '0) return 1'b1;
    // Wrapping bursts are currently not supported.
    if (burst == axi_pkg::BURST_WRAP) return 1'b0;
    // ATOP bursts are not supported.
    if (atop != '0 & len > 0) return 1'b0;
    // The AXI Spec (A3.4.1) only allows splitting non-modifiable transactions ..
    if (!axi_pkg::modifiable(cache)) begin
      // .. if they are INCR bursts and longer than 16 beats.
      return (burst == axi_pkg::BURST_INCR) & (len > 16);
    end
    // All other transactions are supported.
    return 1'b1;
  endfunction
  assign sel_aw_unsupported = ~txn_supported(slv_req.aw.atop, slv_req.aw.burst,
                                              slv_req.aw.cache, slv_req.aw.len);
  assign sel_ar_unsupported = ~txn_supported('0, slv_req.ar.burst,
                                              slv_req.ar.cache, slv_req.ar.len);
  // Respond to unsupported transactions with slave errors.
  axi_rt_err_slv #(
    .AxiIdWidth ( IdWidth               ),
    .axi_req_t  ( axi_req_t             ),
    .axi_resp_t ( axi_resp_t            ),
    .Resp       ( axi_pkg::RESP_SLVERR  ),
    .ATOPs      ( 1'b0                  ),  // The burst splitter does not support ATOPs.
    .MaxTrans   ( 1                     )   // Splitting bursts implies a low-performance bus.
  ) i_err_slv (
    .clk_i,
    .rst_ni,
    .test_i     ( 1'b0              ),
    .slv_req_i  ( unsupported_req   ),
    .slv_resp_o ( unsupported_resp  )
  );

  // --------------------------------------------------
  // AW Channel
  // --------------------------------------------------
  logic           w_cnt_dec, w_cnt_req, w_cnt_gnt, w_cnt_err;
  axi_pkg::len_t  w_cnt_len;
  axi_gran_burst_splitter_ax_chan #(
    .chan_t   ( axi_aw_chan_t ),
    .IdWidth  ( IdWidth       ),
    .MaxTxns  ( MaxWriteTxns  ),
    .CutPath  ( CutPath       )
  ) i_axi_gran_burst_splitter_aw_chan (
    .clk_i,
    .rst_ni,
    .len_limit_i,
    .ax_i           ( act_req.aw           ),
    .ax_valid_i     ( act_req.aw_valid     ),
    .ax_ready_o     ( act_resp.aw_ready    ),
    .ax_o           ( mst_req_o.aw         ),
    .ax_valid_o     ( mst_req_o.aw_valid   ),
    .ax_ready_i     ( mst_resp_i.aw_ready  ),
    .cnt_id_i       ( mst_resp_i.b.id      ),
    .cnt_len_o      ( w_cnt_len            ),
    .cnt_set_err_i  ( mst_resp_i.b.resp[1] ),
    .cnt_err_o      ( w_cnt_err            ),
    .cnt_dec_i      ( w_cnt_dec            ),
    .cnt_req_i      ( w_cnt_req            ),
    .cnt_gnt_o      ( w_cnt_gnt            )
  );

  // --------------------------------------------------
  // W Channel
  // --------------------------------------------------
  // keep a state where we are in the fragmentation of the w
  axi_pkg::len_t w_len_d, w_len_q;
  logic          w_first_d, w_first_q;

  // Feed through, except `last`, which needs to be modified
  always_comb begin : proc_w_frag
    mst_req_o.w        = act_req.w;
    w_len_d            = w_len_q;
    w_first_d          = w_first_q;
    // the entire detection machine is only required if len_limit > 0
    if (len_limit_i != 8'h00) begin
      // only advance the machine if w ready and valid
      if (act_resp.w_ready & act_req.w_valid)  begin
        // if the w is the last in the ingress burst, it is in the egress, in this case last is set by
        // the feed through. We only need to modify if the last is not set upstream
        if (!act_req.w.last) begin
          // default here is last = 0
          mst_req_o.w.last = 1'b0;
          // we are here meaning there are at least two beats remaining in the w.
          // first we need to understand if we are first, bc we need to init the counter otherwise
          if (w_len_q == 8'h00) begin
            if (w_first_q) begin
              // we set the counter and the first flag
              w_len_d   = len_limit_i - 8'h01;
              w_first_d = 1'b0;
            end else begin
              // we are last in sub-burst -> last flag
              w_len_d   = len_limit_i - 8'h01;
              mst_req_o.w.last = 1'b1;
            end
          end else begin
            // decrement counter
            w_len_d = w_len_q - 8'h01;
          end
        end else begin
          // we received a last -> reset first flag
          w_first_d = 1'b1;
        end
      end
    end else begin
      // we operate in the legacy mode -> every w is last
      mst_req_o.w.last = 1'b1;
    end
  end

  assign mst_req_o.w_valid  = act_req.w_valid;
  assign act_resp.w_ready   = mst_resp_i.w_ready;

  // --------------------------------------------------
  // B Channel
  // --------------------------------------------------
  // Filter B response, except for the last one
  enum logic {BReady, BWait} b_state_d, b_state_q;
  logic b_err_d, b_err_q;
  always_comb begin
    mst_req_o.b_ready = 1'b0;
    act_resp.b        = '0;
    act_resp.b_valid  = 1'b0;
    w_cnt_dec         = 1'b0;
    w_cnt_req         = 1'b0;
    b_err_d           = b_err_q;
    b_state_d         = b_state_q;

    unique case (b_state_q)
      BReady: begin
        if (mst_resp_i.b_valid) begin
          w_cnt_req = 1'b1;
          if (w_cnt_gnt) begin
            if (w_cnt_len < ({1'b0, len_limit_i} + 9'h001)) begin
              act_resp.b = mst_resp_i.b;
              if (w_cnt_err) begin
                act_resp.b.resp = axi_pkg::RESP_SLVERR;
              end
              act_resp.b_valid  = 1'b1;
              w_cnt_dec         = 1'b1;
              if (act_req.b_ready) begin
                mst_req_o.b_ready = 1'b1;
              end else begin
                b_state_d = BWait;
                b_err_d   = w_cnt_err;
              end
            end else begin
              mst_req_o.b_ready = 1'b1;
              w_cnt_dec         = 1'b1;
            end
          end
        end
      end
      BWait: begin
        act_resp.b = mst_resp_i.b;
        if (b_err_q) begin
          act_resp.b.resp = axi_pkg::RESP_SLVERR;
        end
        act_resp.b_valid  = 1'b1;
        if (mst_resp_i.b_valid && act_req.b_ready) begin
          mst_req_o.b_ready = 1'b1;
          b_state_d         = BReady;
        end
      end
      default: /*do nothing*/;
    endcase
  end

  // --------------------------------------------------
  // AR Channel
  // --------------------------------------------------
  // See description of `ax_chan` module.
  logic           r_cnt_dec, r_cnt_req, r_cnt_gnt;
  axi_pkg::len_t  r_cnt_len;
  axi_gran_burst_splitter_ax_chan #(
    .chan_t   ( axi_ar_chan_t ),
    .IdWidth  ( IdWidth       ),
    .MaxTxns  ( MaxReadTxns   ),
    .CutPath  ( CutPath       )
  ) i_axi_gran_burst_splitter_ar_chan (
    .clk_i,
    .rst_ni,
    .len_limit_i,
    .ax_i           ( act_req.ar          ),
    .ax_valid_i     ( act_req.ar_valid    ),
    .ax_ready_o     ( act_resp.ar_ready   ),
    .ax_o           ( mst_req_o.ar        ),
    .ax_valid_o     ( mst_req_o.ar_valid  ),
    .ax_ready_i     ( mst_resp_i.ar_ready ),
    .cnt_id_i       ( mst_resp_i.r.id     ),
    .cnt_len_o      ( r_cnt_len           ),
    .cnt_set_err_i  ( 1'b0                ),
    .cnt_err_o      (                     ),
    .cnt_dec_i      ( r_cnt_dec           ),
    .cnt_req_i      ( r_cnt_req           ),
    .cnt_gnt_o      ( r_cnt_gnt           )
  );

  // --------------------------------------------------
  // R Channel
  // --------------------------------------------------
  // Reconstruct `last`, feed rest through.
  logic r_last_d, r_last_q;
  enum logic {RFeedthrough, RWait} r_state_d, r_state_q;
  always_comb begin
    r_cnt_dec         = 1'b0;
    r_cnt_req         = 1'b0;
    r_last_d          = r_last_q;
    r_state_d         = r_state_q;
    mst_req_o.r_ready = 1'b0;
    act_resp.r        = mst_resp_i.r;
    act_resp.r.last   = 1'b0;
    act_resp.r_valid  = 1'b0;

    unique case (r_state_q)
      RFeedthrough: begin
        // If downstream has an R beat and the R counters can give us the remaining length of
        // that burst, ...
        if (mst_resp_i.r_valid) begin
          // if downstream is last
          if (mst_resp_i.r.last) begin
            r_cnt_req = 1'b1;
            if (r_cnt_gnt) begin
              r_last_d = (r_cnt_len < ({1'b0, len_limit_i} + 9'h001));
              act_resp.r.last   = r_last_d;
              // Decrement the counter.
              r_cnt_dec         = 1'b1;
              // Try to forward the beat upstream.
              act_resp.r_valid  = 1'b1;
              if (act_req.r_ready) begin
                // Acknowledge downstream.
                mst_req_o.r_ready = 1'b1;
              end else begin
                // Wait for upstream to become ready.
                r_state_d = RWait;
              end
            end
          end else begin
            // downstream was not last, just a normal read to pass through
            r_last_d = 1'b0;
            act_resp.r.last   = r_last_d;
            // Try to forward the beat upstream.
            act_resp.r_valid  = 1'b1;
            if (act_req.r_ready) begin
              // Acknowledge downstream.
              mst_req_o.r_ready = 1'b1;
            end else begin
              // Wait for upstream to become ready.
              r_state_d = RWait;
            end
          end
        end
      end
      RWait: begin
        act_resp.r.last   = r_last_q;
        act_resp.r_valid  = mst_resp_i.r_valid;
        if (mst_resp_i.r_valid && act_req.r_ready) begin
          mst_req_o.r_ready = 1'b1;
          r_state_d         = RFeedthrough;
        end
      end
      default: /*do nothing*/;
    endcase
  end

  // --------------------------------------------------
  // Flip-Flops
  // --------------------------------------------------
  `FFARN(b_err_q, b_err_d, 1'b0, clk_i, rst_ni)
  `FFARN(b_state_q, b_state_d, BReady, clk_i, rst_ni)
  `FFARN(r_last_q, r_last_d, 1'b0, clk_i, rst_ni)
  `FFARN(r_state_q, r_state_d, RFeedthrough, clk_i, rst_ni)
  `FFARN(w_len_q, w_len_d, 8'h00, clk_i, rst_ni)
  `FFARN(w_first_q, w_first_d, 1'b1, clk_i, rst_ni)

  // --------------------------------------------------
  // Assumptions and assertions
  // --------------------------------------------------
  `ifndef VERILATOR
  // pragma translate_off
  default disable iff (!rst_ni);
  // Inputs
  assume property (@(posedge clk_i) slv_req_i.aw_valid |->
      txn_supported(slv_req_i.aw.atop, slv_req_i.aw.burst, slv_req_i.aw.cache, slv_req_i.aw.len)
    ) else $warning("Unsupported AW transaction received, returning slave error!");
  assume property (@(posedge clk_i) slv_req_i.ar_valid |->
      txn_supported('0, slv_req_i.ar.burst, slv_req_i.ar.cache, slv_req_i.ar.len)
    ) else $warning("Unsupported AR transaction received, returning slave error!");
  // assume property (@(posedge clk_i) slv_req_i.aw_valid |->
  //     slv_req_i.aw.atop == '0 || slv_req_i.aw.atop[5:4] == axi_pkg::ATOP_ATOMICSTORE
  //   ) else $fatal(1, "Unsupported ATOP that gives rise to a R response received,\
  //                    cannot respond in protocol-compliant manner!");
  // Outputs
  assert property (@(posedge clk_i) mst_req_o.aw_valid |-> mst_req_o.aw.len <= len_limit_i)
    else $fatal(1, "AW burst longer than a single beat emitted!");
  assert property (@(posedge clk_i) mst_req_o.ar_valid |-> mst_req_o.ar.len <= len_limit_i)
    else $fatal(1, "AR burst longer than a single beat emitted!");
  // pragma translate_on
  `endif

endmodule
