// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Chaoqun Liang <chaoqun.liang@unibo.it>

module write_guard
  import axi_tmu_pkg::*;
#(
  parameter int unsigned MaxUniqIds   = 32,
  parameter int unsigned MaxWrTxns    = 32,
  parameter type hs_cnt_t             = logic,
  parameter type id_t                 = logic
)(
  input  logic           clk_i,
  input  logic           rst_ni,
  input  logic           reset_clear_i,

  // AXI Write Channel Signals (registered monitor view)
  input  logic           aw_hs_i,
  input  logic           aw_valid_i,
  input  logic           aw_ready_i,
  input  id_t            awid_i,
  input  axi_pkg::len_t  awlen_i,

  input  logic           w_hs_i,
  input  logic           w_valid_i,
  input  logic           w_ready_i,
  input  logic           wlast_i,

  input  logic           b_hs_i,
  input  logic           b_valid_i,
  input  logic           b_ready_i,
  input  id_t            bid_i,
  input  axi_pkg::resp_t bresp_i,

  // Prescaled tick for all counters
  input  logic           prescaled_en_i,

  // Budget thresholds from CSRs
  input  hs_cnt_t        budget_awvld_awrdy_i,  // Stage 1: Shared
  input  hs_cnt_t        budget_owner_wvld_i,   // Stage 2: Shared (owner wait)
  input  hs_cnt_t        budget_wvld_wrdy_i,    // Stage 3: Shared (W first beat)
  input  hs_cnt_t        budget_inter_beat_i,   // Stage 4: Inter-beat liveness budget
  input  hs_cnt_t        budget_wlast_bvld_i,   // Stage 5: Per-ID
  input  hs_cnt_t        budget_bvld_brdy_i,    // Stage 6: Per-ID

  output logic           reset_req_o,
  output logic           timeout_o,
  output id_t            abort_id_o,

  output logic           evt_ovf_o,
  output id_t            evt_ovf_id_o,

  input  logic           fab_all_req_i,   // ask to drain all writes as SLVERR
  output logic           fab_b_valid_o,   // one fabricated B this cycle
  output id_t            fab_b_id_o,      // its BID

  // Latency profiling outputs (10-bit CSRs)
  output logic [9:0]     lat_awvld_wfirst_o,
  output logic [9:0]     lat_wvld_wrdy_o,
  output logic [9:0]     lat_wvld_wlast_o,
  output logic [9:0]     lat_wlast_bvld_o,
  output logic [9:0]     lat_bvld_brdy_o,

  output logic                        fault_pulse_o,
  output axi_tmu_pkg::tmu_phase_t     fault_phase_o,
  output axi_tmu_pkg::tmu_fault_type_t fault_type_o
);

  localparam int HtCapacity          = (MaxUniqIds <= MaxWrTxns) ? MaxUniqIds : MaxWrTxns;
  localparam int unsigned HtIdxWidth = cf_math_pkg::idx_width(HtCapacity);
  localparam int unsigned LdIdxWidth = cf_math_pkg::idx_width(MaxWrTxns);
  localparam int unsigned PtrWidth   = (MaxWrTxns > 1) ? $clog2(MaxWrTxns) : 1;

  typedef logic [HtIdxWidth-1:0] ht_idx_t;
  typedef logic [LdIdxWidth-1:0] ld_idx_t;

  // Head-tail Table entry (with Stage 5/6 counters)
  typedef struct packed {
    id_t        id;
    ld_idx_t    head, tail;
    logic       free;
    hs_cnt_t    cnt_wlast_bvalid;  // stage5: per-id (OoO completion)
    hs_cnt_t    cnt_bvalid_bready; // stage6: per-id (back-pressure)
    logic       waiting_bvalid;    // Waiting for B_VALID
    logic       waiting_bready;    // Waiting for B_READY
  } head_tail_t;

  // Linked data entry (per-transaction tracking)
  typedef struct packed {
    logic [8:0]    expected_beats;  // AWLEN+1 (9 bits per txn)
    write_state_t  write_state;
    ht_idx_t       ht_idx;
    ld_idx_t       next;
    logic          free;
  } linked_wr_data_t;

  // Table Storage
  head_tail_t      [HtCapacity-1:0] head_tail_n, head_tail_q;
  linked_wr_data_t [MaxWrTxns-1:0]  linked_data_n, linked_data_q;

  // W-owner FIFO
  ld_idx_t         [MaxWrTxns-1:0]  w_fifo_q, w_fifo_n;
  logic            [PtrWidth-1:0]   wr_ptr_q, wr_ptr_n;
  logic            [PtrWidth-1:0]   rd_ptr_q, rd_ptr_n;
  logic                             fifo_full_q, fifo_full_n;
  logic                             fifo_empty_q, fifo_empty_n;

  ld_idx_t active_idx;
  assign active_idx = fifo_empty_q ? '0 : w_fifo_q[rd_ptr_q];

  // ==========================================================================
  // STAGE 1: AW Pre-Handshake (AWVALID -> AWREADY)
  // ==========================================================================
  logic aw_valid_sticky, aw_ready_sticky;
  logic timeout_aw, reset_aw;
  id_t  abort_id_aw;

  sticky i_awvalid_sticky (
    .clk_i,
    .rst_ni,
    .release_i ( prescaled_en_i  ),
    .sticky_i  ( aw_valid_i      ),
    .sticky_o  ( aw_valid_sticky )
  );

  sticky i_awready_sticky (
    .clk_i,
    .rst_ni,
    .release_i ( prescaled_en_i  ),
    .sticky_i  ( aw_ready_i      ),
    .sticky_o  ( aw_ready_sticky )
  );

  tmu_hs_counter #(
    .hs_cnt_t ( hs_cnt_t ),
    .id_t     ( id_t     )
  ) i_aw_prehs (
    .clk_i,
    .rst_ni,
    .prescaled_en_i,
    .valid_i    ( aw_valid_sticky && !fab_all_req_i ),
    .ready_i    ( aw_ready_sticky                   ),
    .id_i       ( awid_i                            ),
    .budget_i   ( budget_awvld_awrdy_i              ),
    .timeout_o  ( timeout_aw                        ),
    .reset_o    ( reset_aw                          ),
    .abort_id_o ( abort_id_aw                       )
  );

  // ==========================================================================
  // STAGE 2: Owner Wait for W_VALID (AW_HS -> W_VALID)
  // ==========================================================================
  logic w_valid_sticky, w_ready_sticky;
  hs_cnt_t shared_owner_wait_q, shared_owner_wait_n;
  logic    owner_waiting, timeout_owner_wait, first_w_valid_seen;
  id_t     owner_awid;

  sticky i_wvalid_sticky (
    .clk_i,
    .rst_ni,
    .release_i ( prescaled_en_i ),
    .sticky_i  ( w_valid_i      ),
    .sticky_o  ( w_valid_sticky )
  );

  sticky i_wready_sticky (
    .clk_i,
    .rst_ni,
    .release_i ( prescaled_en_i ),
    .sticky_i  ( w_ready_i      ),
    .sticky_o  ( w_ready_sticky )
  );

  assign owner_waiting = !fifo_empty_q &&
                         !linked_data_q[active_idx].free &&
                         (linked_data_q[active_idx].write_state == WRITE_ADDRESS);

  assign owner_awid         = head_tail_q[linked_data_q[active_idx].ht_idx].id;
  assign first_w_valid_seen = owner_waiting && w_valid_sticky;

  always_comb begin
    shared_owner_wait_n = shared_owner_wait_q;
    timeout_owner_wait  = 1'b0;

    if (!fab_all_req_i) begin
      if (owner_waiting && !w_valid_sticky && (shared_owner_wait_q >= budget_owner_wvld_i)) begin
        timeout_owner_wait = 1'b1;
      end

      if (owner_waiting && !w_valid_sticky && prescaled_en_i) begin
        if (shared_owner_wait_q < budget_owner_wvld_i) begin
          shared_owner_wait_n = shared_owner_wait_q + 1'b1;
        end
      end
    end

    if (first_w_valid_seen || !owner_waiting || fab_all_req_i) begin
      shared_owner_wait_n = '0;
    end
  end

  // ==========================================================================
  // STAGE 3: W-first handshake (W_VALID -> W_READY on first beat)
  // ==========================================================================
  logic timeout_wfirst, reset_wfirst;
  id_t  abort_id_wfirst;

  tmu_hs_counter #(
    .hs_cnt_t ( hs_cnt_t ),
    .id_t     ( id_t     )
  ) i_wfirst (
    .clk_i,
    .rst_ni,
    .prescaled_en_i,
    .valid_i    ( owner_waiting && w_valid_sticky && !fab_all_req_i ),
    .ready_i    ( owner_waiting && w_ready_sticky                   ),
    .id_i       ( owner_awid                                        ),
    .budget_i   ( budget_wvld_wrdy_i                                ),
    .timeout_o  ( timeout_wfirst                                    ),
    .reset_o    ( reset_wfirst                                      ),
    .abort_id_o ( abort_id_wfirst                                   )
  );

  // ==========================================================================
  // STAGE 4: W Channel Liveness + Beat Counter (Both Shared)
  // ==========================================================================
  hs_cnt_t    w_liveness_q, w_liveness_n;
  logic [8:0] w_beat_cnt_q, w_beat_cnt_n;

  logic timeout_stage4, reset_stage4;
  id_t  timeout_id_stage4;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      shared_owner_wait_q <= '0;
      w_liveness_q        <= '0;
      w_beat_cnt_q        <= '0;
    end else if (reset_clear_i) begin
      shared_owner_wait_q <= '0;
      w_liveness_q        <= '0;
      w_beat_cnt_q        <= '0;
    end else begin
      shared_owner_wait_q <= shared_owner_wait_n;
      w_liveness_q        <= w_liveness_n;
      w_beat_cnt_q        <= w_beat_cnt_n;
    end
  end

  // ==========================================================================
  // STAGE 5-6 & Inflight Transaction Manager
  // ==========================================================================
  logic timeout_stage5, timeout_stage6, reset_stage5;
  id_t  timeout_id_stage5, timeout_id_stage6;

  logic proto_err, reset_proto;
  id_t  abort_id_proto;

  tmu_wr_inflight #(
    .MaxWrTxns     ( MaxWrTxns        ),
    .HtCapacity    ( HtCapacity       ),
    .linked_data_t ( linked_wr_data_t ),
    .head_tail_t   ( head_tail_t      ),
    .ht_idx_t      ( ht_idx_t         ),
    .ld_idx_t      ( ld_idx_t         ),
    .id_t          ( id_t             ),
    .hs_cnt_t      ( hs_cnt_t         )
  ) i_wr_inflight (
    .prescaled_en_i       ( prescaled_en_i       ),
    .reset_clear_i        ( reset_clear_i        ),
    // FIFO interface
    .w_fifo_q_i           ( w_fifo_q             ),
    .w_fifo_n_o           ( w_fifo_n             ),
    .wr_ptr_q_i           ( wr_ptr_q             ),
    .rd_ptr_q_i           ( rd_ptr_q             ),
    .fifo_full_q_i        ( fifo_full_q          ),
    .fifo_empty_q_i       ( fifo_empty_q         ),
    .wr_ptr_n_o           ( wr_ptr_n             ),
    .rd_ptr_n_o           ( rd_ptr_n             ),
    .fifo_full_n_o        ( fifo_full_n          ),
    .fifo_empty_n_o       ( fifo_empty_n         ),
    .active_idx_i         ( active_idx           ),

    // Cycle-accurate AXI signals (no sticky stretching on handshakes)
    .aw_hs_i              ( aw_hs_i              ),
    .awid_q_i             ( awid_i               ),
    .awlen_q_i            ( awlen_i              ),
    .w_hs_i               ( w_hs_i               ),
    .w_valid_i            ( w_valid_i            ),
    .w_ready_i            ( w_ready_i            ),
    .wlast_q_i            ( wlast_i              ),
    .b_hs_i               ( b_hs_i               ),
    .b_ready_i            ( b_ready_i            ),
    .b_valid_i            ( b_valid_i            ),
    .bid_i                ( bid_i                ),

    // Table interfaces
    .head_tail_q_i        ( head_tail_q          ),
    .head_tail_n_o        ( head_tail_n          ),
    .linked_data_q_i      ( linked_data_q        ),
    .linked_data_n_o      ( linked_data_n        ),

    // Status outputs
    .reset_req_o          ( reset_proto          ),
    .evt_ovf_o            ( evt_ovf_o            ),
    .evt_ovf_id_o         ( evt_ovf_id_o         ),
    .abort_id_o           ( abort_id_proto       ),
    .proto_err_o          ( proto_err            ),

    // Fabrication
    .fab_all_req_i        ( fab_all_req_i        ),
    .fab_b_valid_o        ( fab_b_valid_o        ),
    .fab_b_id_o           ( fab_b_id_o           ),

    .budget_wlast_bvld_i  ( budget_wlast_bvld_i  ),
    .budget_bvld_brdy_i   ( budget_bvld_brdy_i   ),
    .budget_w_liveness_i  ( budget_inter_beat_i  ),

    // Shared Stage 4 counters
    .w_liveness_q_i       ( w_liveness_q         ),
    .w_liveness_n_o       ( w_liveness_n         ),
    .w_beat_cnt_q_i       ( w_beat_cnt_q         ),
    .w_beat_cnt_n_o       ( w_beat_cnt_n         ),

    .timeout_stage4_o     ( timeout_stage4       ),
    .timeout_id_stage4_o  ( timeout_id_stage4    ),
    .reset_stage4_o       ( reset_stage4         ),

    .timeout_stage5_o     ( timeout_stage5       ),
    .timeout_stage6_o     ( timeout_stage6       ),
    .reset_stage5_o       ( reset_stage5         ),
    .timeout_id_stage5_o  ( timeout_id_stage5    ),
    .timeout_id_stage6_o  ( timeout_id_stage6    )
  );

  // Table Storage Flops
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int i = 0; i < HtCapacity; i++) begin
        head_tail_q[i] <= '{free: 1'b1, default: '0};
      end
      for (int i = 0; i < MaxWrTxns; i++) begin
        linked_data_q[i] <= '{free: 1'b1, default: '0};
      end
      w_fifo_q     <= '0;
      wr_ptr_q     <= '0;
      rd_ptr_q     <= '0;
      fifo_full_q  <= 1'b0;
      fifo_empty_q <= 1'b1;
    end else begin
      head_tail_q   <= head_tail_n;
      linked_data_q <= linked_data_n;
      w_fifo_q      <= w_fifo_n;
      wr_ptr_q      <= wr_ptr_n;
      rd_ptr_q      <= rd_ptr_n;
      fifo_full_q   <= fifo_full_n;
      fifo_empty_q  <= fifo_empty_n;
    end
  end

  // ==========================================================================
  // Self-Reported Subordinate Error Detection (TMU_FLT_SLVERR)
  // ==========================================================================
  logic slverr_b;
  assign slverr_b = !fab_all_req_i && b_hs_i && (bresp_i != axi_pkg::RESP_OKAY) &&
                    (bresp_i != axi_pkg::RESP_EXOKAY);

  // ==========================================================================
  // Phase Latency Profiling Counters (10-bit High-Watermark CSRs)
  // ==========================================================================
  logic [9:0] cur_awvld_wfirst_q, max_awvld_wfirst_q;
  logic [9:0] cur_wvld_wrdy_q,    max_wvld_wrdy_q;
  logic [9:0] cur_wvld_wlast_q,   max_wvld_wlast_q;
  logic [9:0] max_wlast_bvld_q,   max_bvld_brdy_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cur_awvld_wfirst_q <= '0;
      max_awvld_wfirst_q <= '0;
      cur_wvld_wrdy_q    <= '0;
      max_wvld_wrdy_q    <= '0;
      cur_wvld_wlast_q   <= '0;
      max_wvld_wlast_q   <= '0;
      max_wlast_bvld_q   <= '0;
      max_bvld_brdy_q    <= '0;
    end else if (reset_clear_i) begin
      cur_awvld_wfirst_q <= '0;
      max_awvld_wfirst_q <= '0;
      cur_wvld_wrdy_q    <= '0;
      max_wvld_wrdy_q    <= '0;
      cur_wvld_wlast_q   <= '0;
      max_wvld_wlast_q   <= '0;
      max_wlast_bvld_q   <= '0;
      max_bvld_brdy_q    <= '0;
    end else begin
      // 1. latency_awvld_wfirst
      if (owner_waiting && w_valid_i) begin
        if (cur_awvld_wfirst_q > max_awvld_wfirst_q)
          max_awvld_wfirst_q <= cur_awvld_wfirst_q;
        cur_awvld_wfirst_q <= '0;
      end else if ((aw_valid_i && !aw_ready_i) || (owner_waiting && !w_valid_i)) begin
        if (cur_awvld_wfirst_q != 10'h3ff)
          cur_awvld_wfirst_q <= cur_awvld_wfirst_q + 10'd1;
      end

      // 2. latency_wvld_wrdy
      if (w_hs_i) begin
        if (cur_wvld_wrdy_q > max_wvld_wrdy_q)
          max_wvld_wrdy_q <= cur_wvld_wrdy_q;
        cur_wvld_wrdy_q <= '0;
      end else if (w_valid_i && !w_ready_i) begin
        if (cur_wvld_wrdy_q != 10'h3ff)
          cur_wvld_wrdy_q <= cur_wvld_wrdy_q + 10'd1;
      end

      // 3. latency_wvld_wlast
      if (w_hs_i && wlast_i) begin
        if (cur_wvld_wlast_q > max_wvld_wlast_q)
          max_wvld_wlast_q <= cur_wvld_wlast_q;
        cur_wvld_wlast_q <= '0;
      end else if (!fifo_empty_q && (w_valid_i || (linked_data_q[active_idx].write_state == WRITE_DATA))) begin
        if (cur_wvld_wlast_q != 10'h3ff)
          cur_wvld_wlast_q <= cur_wvld_wlast_q + 10'd1;
      end

      // 4 & 5. latency_wlast_bvld and latency_bvld_brdy (tracked across active HT buckets)
      for (int k = 0; k < HtCapacity; k++) begin
        if (!head_tail_q[k].free) begin
          if (10'(head_tail_q[k].cnt_wlast_bvalid) > max_wlast_bvld_q)
            max_wlast_bvld_q <= 10'(head_tail_q[k].cnt_wlast_bvalid);
          if (10'(head_tail_q[k].cnt_bvalid_bready) > max_bvld_brdy_q)
            max_bvld_brdy_q <= 10'(head_tail_q[k].cnt_bvalid_bready);
        end
      end
    end
  end

  assign lat_awvld_wfirst_o = max_awvld_wfirst_q;
  assign lat_wvld_wrdy_o    = max_wvld_wrdy_q;
  assign lat_wvld_wlast_o   = max_wvld_wlast_q;
  assign lat_wlast_bvld_o   = max_wlast_bvld_q;
  assign lat_bvld_brdy_o    = max_bvld_brdy_q;

  // ==========================================================================
  // Fault Aggregation and Prioritization
  // ==========================================================================
  always_comb begin
    abort_id_o    = '0;
    fault_pulse_o = 1'b0;
    fault_phase_o = axi_tmu_pkg::PH_NONE;
    fault_type_o  = axi_tmu_pkg::TMU_FLT_NONE;

    if (timeout_aw) begin
      abort_id_o    = abort_id_aw;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_AW;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_TIMEOUT;
    end else if (timeout_owner_wait) begin
      abort_id_o    = owner_awid;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_WOWN;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_TIMEOUT;
    end else if (timeout_wfirst) begin
      abort_id_o    = abort_id_wfirst;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_WFIRST;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_TIMEOUT;
    end else if (timeout_stage4) begin
      abort_id_o    = timeout_id_stage4;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_WDATA;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_TIMEOUT;
    end else if (timeout_stage5) begin
      abort_id_o    = timeout_id_stage5;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_W2B;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_TIMEOUT;
    end else if (timeout_stage6) begin
      abort_id_o    = timeout_id_stage6;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_B2BR;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_TIMEOUT;
    end else if (proto_err) begin
      abort_id_o    = abort_id_proto;
      fault_pulse_o = 1'b1;
      fault_phase_o = (w_hs_i && !b_hs_i) ? axi_tmu_pkg::PH_WDATA : axi_tmu_pkg::PH_B2BR;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_PROTO;
    end else if (slverr_b) begin
      abort_id_o    = bid_i;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_B2BR;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_SLVERR;
    end else if (evt_ovf_o) begin
      abort_id_o    = evt_ovf_id_o;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_AW;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_OVERFLOW;
    end
  end

  assign timeout_o   = timeout_aw | timeout_owner_wait | timeout_wfirst |
                       timeout_stage4 | timeout_stage5 | timeout_stage6;

  assign reset_req_o = reset_aw | reset_wfirst | reset_stage4 | reset_stage5 | reset_proto | slverr_b;

  `ifndef SYNTHESIS
  initial begin
    assert (MaxWrTxns > 0)
      else $fatal(1, "[write_guard] MaxWrTxns must be > 0");
    assert (MaxUniqIds > 0)
      else $fatal(1, "[write_guard] MaxUniqIds must be > 0");
    if (MaxWrTxns > 1) begin
      assert ((1 << PtrWidth) == MaxWrTxns)
        else $fatal(1, "[write_guard] MaxWrTxns must be power-of-two for FIFO");
    end
  end
  `endif

endmodule