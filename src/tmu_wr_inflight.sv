// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Chaoqun Liang <chaoqun.liang@unibo.it>

// ID-Level Tracking (ILT) Write Inflight Manager:
// - O(N_ID) state: tracks num_txn and b_timeout_cnt per active ID
// - No per-transaction linked_data_q or W-FIFO storage

module tmu_wr_inflight
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
  input  track_cnt_t                    budget_b2b_i,

  // AXI signals
  input  logic                          aw_hs_i,
  input  id_t                           awid_q_i,

  input  logic                          b_hs_i,
  input  id_t                           bid_i,
  input  logic                          b_ready_i,

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
  output logic                          fab_b_valid_o,
  output id_t                           fab_b_id_o,

  // Timeout outputs
  output logic                          timeout_b_o,
  output id_t                           timeout_id_b_o
);

  logic [HtCapacity-1:0] match_aw_oh, match_b_oh, ht_free_oh;

  ht_idx_t match_aw_idx, match_b_idx, ht_free_idx;
  logic aw_id_match, b_id_match, ht_free_valid;

  generate
    for (genvar i = 0; i < HtCapacity; i++) begin : gen_ht_match
      assign match_aw_oh[i] = !head_tail_q_i[i].free &&
                              (head_tail_q_i[i].id == awid_q_i) &&
                              aw_hs_i;
      assign match_b_oh[i]  = !head_tail_q_i[i].free &&
                              (head_tail_q_i[i].id == bid_i) &&
                              b_hs_i;
      assign ht_free_oh[i]  = head_tail_q_i[i].free;
    end
  endgenerate

  assign aw_id_match   = |match_aw_oh;
  assign b_id_match    = |match_b_oh;
  assign ht_free_valid = |ht_free_oh;

  onehot_to_bin #(.ONEHOT_WIDTH(HtCapacity)) i_bin_aw (.onehot(match_aw_oh), .bin(match_aw_idx));
  onehot_to_bin #(.ONEHOT_WIDTH(HtCapacity)) i_bin_b  (.onehot(match_b_oh),  .bin(match_b_idx));
  lzc #(.WIDTH(HtCapacity), .MODE(0)) i_ff_ht (.in_i(ht_free_oh), .cnt_o(ht_free_idx), .empty_o());

  // Fabrication Logic
  logic    any_id_nonempty;
  ht_idx_t pick_idx;
  id_t     pick_bid;

  always_comb begin
    any_id_nonempty = 1'b0;
    pick_idx        = '0;
    pick_bid        = '0;
    if (fab_all_req_i) begin
      for (int i = 0; i < HtCapacity; i++) begin
        if (!head_tail_q_i[i].free && (head_tail_q_i[i].num_txn > 0)) begin
          any_id_nonempty = 1'b1;
          pick_idx        = ht_idx_t'(i);
          pick_bid        = head_tail_q_i[i].id;
          break;
        end
      end
    end
  end

  assign fab_b_valid_o = any_id_nonempty;
  assign fab_b_id_o    = pick_bid;

  logic resources_full;

  always_comb begin : proc_wr_queue
    head_tail_n_o  = head_tail_q_i;
    reset_req_o    = 1'b0;
    proto_err_o    = 1'b0;
    evt_ovf_o      = 1'b0;
    evt_ovf_id_o   = '0;
    abort_id_o     = '0;

    timeout_b_o    = 1'b0;
    timeout_id_b_o = '0;

    // Per-ID timeout monitoring (when not fabricating)
    if (!fab_all_req_i) begin
      for (int i = 0; i < HtCapacity; i++) begin : proc_per_id_timeout
        if (!head_tail_q_i[i].free && (head_tail_q_i[i].num_txn > 0)) begin
          if (head_tail_q_i[i].b_timeout_cnt >= budget_b2b_i) begin
            timeout_b_o    = 1'b1;
            timeout_id_b_o = head_tail_q_i[i].id;
          end

          if (prescaled_en_i && (head_tail_q_i[i].b_timeout_cnt < budget_b2b_i)) begin
            head_tail_n_o[i].b_timeout_cnt = head_tail_q_i[i].b_timeout_cnt + 1'b1;
          end
        end
      end
    end

    // Normal B handshake handling (when not fabricating)
    if (b_hs_i && !fab_all_req_i) begin
      if (!b_id_match) begin
        proto_err_o = 1'b1;
        reset_req_o = 1'b1;
        abort_id_o  = bid_i;
      end else begin
        head_tail_n_o[match_b_idx].b_timeout_cnt = '0;
        head_tail_n_o[match_b_idx].num_txn       = head_tail_q_i[match_b_idx].num_txn - 1'b1;

        if (head_tail_q_i[match_b_idx].num_txn == 1) begin
          head_tail_n_o[match_b_idx]      = '0;
          head_tail_n_o[match_b_idx].free = 1'b1;
        end
      end
    end

    resources_full = (!aw_id_match && !ht_free_valid) ||
                     (aw_id_match && !(head_tail_q_i[match_aw_idx].num_txn < MaxTxnsPerId));

    // AW handshake - enqueue
    if (aw_hs_i) begin : proc_txn_enqueue
      if (resources_full) begin
        if (!fab_all_req_i) begin
          evt_ovf_o    = 1'b1;
          evt_ovf_id_o = awid_q_i;
        end
      end else begin
        if (!aw_id_match) begin
          head_tail_n_o[ht_free_idx] = '{
            id:            awid_q_i,
            num_txn:       1,
            b_timeout_cnt: '0,
            free:          1'b0
          };
        end else begin
          // Simultaneous AW Enqueue / B Dequeue Collision Handler
          if (!fab_all_req_i && b_hs_i && b_id_match && (match_b_idx == match_aw_idx)) begin
            if (head_tail_q_i[match_aw_idx].num_txn == 1) begin
              head_tail_n_o[match_aw_idx].free          = 1'b0;
              head_tail_n_o[match_aw_idx].id            = awid_q_i;
              head_tail_n_o[match_aw_idx].num_txn       = 1;
              head_tail_n_o[match_aw_idx].b_timeout_cnt = '0;
            end else begin
              head_tail_n_o[match_aw_idx].num_txn = head_tail_q_i[match_aw_idx].num_txn;
            end
          end else if (fab_all_req_i && fab_b_valid_o && b_ready_i && (pick_idx == match_aw_idx)) begin
            // Collision during fabrication drain
            head_tail_n_o[match_aw_idx].free    = 1'b0;
            head_tail_n_o[match_aw_idx].id      = awid_q_i;
            head_tail_n_o[match_aw_idx].num_txn = head_tail_q_i[match_aw_idx].num_txn;
          end else begin
            head_tail_n_o[match_aw_idx].num_txn = head_tail_q_i[match_aw_idx].num_txn + 1'b1;
          end
        end
      end
    end

    // Fabrication drain (when not colliding with same-ID AW enqueue above)
    if (fab_all_req_i && fab_b_valid_o && b_ready_i) begin
      if (!(aw_hs_i && !resources_full && aw_id_match && (pick_idx == match_aw_idx))) begin
        if (head_tail_q_i[pick_idx].num_txn == 1) begin
          head_tail_n_o[pick_idx] = '{free: 1'b1, default: '0};
        end else begin
          head_tail_n_o[pick_idx].num_txn = head_tail_q_i[pick_idx].num_txn - 1'b1;
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