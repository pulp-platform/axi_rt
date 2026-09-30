// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Chaoqun Liang <chaoqun.liang@unibo.it>

// ID-Level Tracking (ILT) Read Inflight Manager:
// - O(N_ID) state: tracks num_txn and r_timeout_cnt per active ID
// - No per-transaction linked_data_q storage

module tmu_rd_inflight
  import axi_tmu_pkg::*;
#(
  parameter int unsigned HtCapacity   = 1,
  parameter int unsigned MaxTxnsPerId = 1,
  parameter type id_queue_t           = logic,
  parameter type ht_idx_t             = logic,
  parameter type track_cnt_t          = logic,
  parameter type id_t                 = logic
)(
  input  logic                          prescaled_en_i,
  input  logic                          reset_clear_i,
  input  logic [11:0]                   budget_r2r_i,

  // AXI signals
  input  logic                          ar_hs_i,
  input  id_t                           arid_i,

  input  logic                          r_last_i,
  input  logic                          r_hs_i,
  input  id_t                           rid_i,
  input  logic                          r_ready_i,

  // Status
  output logic                          reset_req_o,
  output logic                          proto_err_o,
  output id_t                           abort_id_o,

  input  id_queue_t [HtCapacity-1:0]    head_tail_q_i,
  output id_queue_t [HtCapacity-1:0]    head_tail_n_o,

  // TMU overflow
  output logic                          evt_ovf_o,
  output id_t                           evt_ovf_id_o,

  // Cut-and-drain fabrication
  input  logic                          fab_all_req_i,
  output logic                          fab_r_valid_o,
  output id_t                           fab_r_id_o,

  // Timeout outputs
  output logic                          timeout_r_o,
  output id_t                           timeout_id_r_o
);

  logic [HtCapacity-1:0] match_ar_oh, match_r_oh, ht_free_oh;

  ht_idx_t match_ar_idx, match_r_idx, ht_free_idx;
  logic ar_id_match, r_id_match, ht_free_valid;

  generate
    for (genvar i = 0; i < HtCapacity; i++) begin : g_ht
      assign match_ar_oh[i] = !head_tail_q_i[i].free && (head_tail_q_i[i].id == arid_i) && ar_hs_i;
      assign match_r_oh[i]  = !head_tail_q_i[i].free && (head_tail_q_i[i].id == rid_i) && r_hs_i;
      assign ht_free_oh[i]  = head_tail_q_i[i].free;
    end
  endgenerate

  assign ar_id_match   = |match_ar_oh;
  assign r_id_match    = |match_r_oh;
  assign ht_free_valid = |ht_free_oh;

  onehot_to_bin #(.ONEHOT_WIDTH(HtCapacity)) i_bin_ar (.onehot(match_ar_oh), .bin(match_ar_idx));
  onehot_to_bin #(.ONEHOT_WIDTH(HtCapacity)) i_bin_r  (.onehot(match_r_oh),  .bin(match_r_idx));
  lzc #(.WIDTH(HtCapacity), .MODE(0)) i_ff_ht (.in_i(ht_free_oh), .cnt_o(ht_free_idx), .empty_o());

  logic    any_rid_nonempty;
  ht_idx_t pick_ridx;
  id_t     pick_rid;

  always_comb begin
    any_rid_nonempty = 1'b0;
    pick_ridx        = '0;
    pick_rid         = '0;
    if (fab_all_req_i) begin
      for (int j = 0; j < HtCapacity; j++) begin
        if (!head_tail_q_i[j].free && (head_tail_q_i[j].num_txn > 0)) begin
          any_rid_nonempty = 1'b1;
          pick_ridx        = ht_idx_t'(j);
          pick_rid         = head_tail_q_i[j].id;
          break;
        end
      end
    end
  end

  assign fab_r_valid_o = any_rid_nonempty;
  assign fab_r_id_o    = pick_rid;

  logic resources_full;

  always_comb begin
    head_tail_n_o  = head_tail_q_i;

    reset_req_o    = 1'b0;
    abort_id_o     = '0;
    proto_err_o    = 1'b0;
    evt_ovf_o      = 1'b0;
    evt_ovf_id_o   = '0;

    timeout_r_o    = 1'b0;
    timeout_id_r_o = '0;

    // Per-ID timeout monitoring (when not fabricating)
    if (!fab_all_req_i) begin
      for (int i = 0; i < HtCapacity; i++) begin : proc_per_id_timeout
        if (!head_tail_q_i[i].free && (head_tail_q_i[i].num_txn > 0)) begin
          if (head_tail_q_i[i].r_timeout_cnt >= budget_r2r_i) begin
            timeout_r_o    = 1'b1;
            timeout_id_r_o = head_tail_q_i[i].id;
          end

          if (prescaled_en_i && (head_tail_q_i[i].r_timeout_cnt < budget_r2r_i)) begin
            head_tail_n_o[i].r_timeout_cnt = head_tail_q_i[i].r_timeout_cnt + 1'b1;
          end
        end
      end
    end

    // Normal R handshake handling (when not fabricating)
    if (r_hs_i && !fab_all_req_i) begin
      if (!r_id_match) begin
        proto_err_o = 1'b1;
        reset_req_o = 1'b1;
        abort_id_o  = rid_i;
      end else if (r_last_i) begin
        head_tail_n_o[match_r_idx].r_timeout_cnt = '0;
        head_tail_n_o[match_r_idx].num_txn       = head_tail_q_i[match_r_idx].num_txn - 1'b1;

        if (head_tail_q_i[match_r_idx].num_txn == 1) begin
          head_tail_n_o[match_r_idx]      = '0;
          head_tail_n_o[match_r_idx].free = 1'b1;
        end
      end
    end

    resources_full = (!ar_id_match && !ht_free_valid) ||
                     (ar_id_match && !(head_tail_q_i[match_ar_idx].num_txn < MaxTxnsPerId));

    // AR handshake - enqueue (FIX: restored missing !ar_id_match allocation!)
    if (ar_hs_i) begin : proc_txn_enqueue
      if (resources_full) begin
        if (!fab_all_req_i) begin
          evt_ovf_o    = 1'b1;
          evt_ovf_id_o = arid_i;
        end
      end else begin
        if (!ar_id_match) begin
          // New ARID allocation
          head_tail_n_o[ht_free_idx] = '{
            id:            arid_i,
            num_txn:       1,
            r_timeout_cnt: '0,
            free:          1'b0
          };
        end else begin
          // Simultaneous AR Enqueue / RLAST Dequeue Collision Handler
          if (!fab_all_req_i && r_hs_i && r_last_i && r_id_match && (match_r_idx == match_ar_idx)) begin
            if (head_tail_q_i[match_ar_idx].num_txn == 1) begin
              head_tail_n_o[match_ar_idx].free          = 1'b0;
              head_tail_n_o[match_ar_idx].id            = arid_i;
              head_tail_n_o[match_ar_idx].num_txn       = 1;
              head_tail_n_o[match_ar_idx].r_timeout_cnt = '0;
            end else begin
              head_tail_n_o[match_ar_idx].num_txn = head_tail_q_i[match_ar_idx].num_txn;
            end
          end else if (fab_all_req_i && fab_r_valid_o && r_ready_i && (pick_ridx == match_ar_idx)) begin
            // Collision during fabrication drain
            head_tail_n_o[match_ar_idx].free    = 1'b0;
            head_tail_n_o[match_ar_idx].id      = arid_i;
            head_tail_n_o[match_ar_idx].num_txn = head_tail_q_i[match_ar_idx].num_txn;
          end else begin
            head_tail_n_o[match_ar_idx].num_txn = head_tail_q_i[match_ar_idx].num_txn + 1'b1;
          end
        end
      end
    end

    // Fabrication drain
    if (fab_all_req_i && fab_r_valid_o && r_ready_i) begin
      if (!(ar_hs_i && !resources_full && ar_id_match && (pick_ridx == match_ar_idx))) begin
        if (head_tail_q_i[pick_ridx].num_txn == 1) begin
          head_tail_n_o[pick_ridx] = '{free: 1'b1, default: '0};
        end else begin
          head_tail_n_o[pick_ridx].num_txn = head_tail_q_i[pick_ridx].num_txn - 1'b1;
        end
      end
    end

    // Clear all tables on external reset acknowledgment
    if (reset_clear_i) begin
      for (int n = 0; n < HtCapacity; n++) begin
        head_tail_n_o[n] = '{free: 1'b1, default: '0};
      end
    end
  end

endmodule