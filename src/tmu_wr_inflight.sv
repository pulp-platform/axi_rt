// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Chaoqun Liang <chaoqun.liang@unibo.it>

module tmu_wr_inflight
  import axi_tmu_pkg::*;
#(
  parameter int unsigned MaxWrTxns    = 1,
  parameter int unsigned HtCapacity   = 1,
  parameter int unsigned PtrWidth     = $clog2(MaxWrTxns),
  parameter type linked_data_t        = logic,
  parameter type head_tail_t          = logic,
  parameter type ht_idx_t             = logic,
  parameter type ld_idx_t             = logic,
  parameter type id_t                 = logic,
  parameter type hs_cnt_t             = logic
)(
  input  logic                          prescaled_en_i,
  input  logic                          reset_clear_i,

  // W-owner FIFO (array of LD indices)
  input  ld_idx_t  [MaxWrTxns-1:0]      w_fifo_q_i,
  output ld_idx_t  [MaxWrTxns-1:0]      w_fifo_n_o,

  input  logic [PtrWidth-1:0]           wr_ptr_q_i,
  input  logic [PtrWidth-1:0]           rd_ptr_q_i,
  input  logic                          fifo_full_q_i,
  input  logic                          fifo_empty_q_i,

  output logic [PtrWidth-1:0]           wr_ptr_n_o,
  output logic [PtrWidth-1:0]           rd_ptr_n_o,
  output logic                          fifo_full_n_o,
  output logic                          fifo_empty_n_o,
  input  ld_idx_t                       active_idx_i,

  // AXI signals
  input  logic                          aw_hs_i,
  input  id_t                           awid_q_i,
  input  axi_pkg::len_t                 awlen_q_i,

  input  logic                          w_hs_i,
  input  logic                          w_valid_i,
  input  logic                          w_ready_i,
  input  logic                          wlast_q_i,

  input  logic                          b_hs_i,
  input  id_t                           bid_i,
  input  logic                          b_valid_i,
  input  logic                          b_ready_i,

  // Status
  output logic                          reset_req_o,
  output logic                          proto_err_o,
  output id_t                           abort_id_o,

  // Tables
  input  head_tail_t [HtCapacity-1:0]   head_tail_q_i,
  output head_tail_t [HtCapacity-1:0]   head_tail_n_o,
  input  linked_data_t [MaxWrTxns-1:0]  linked_data_q_i,
  output linked_data_t [MaxWrTxns-1:0]  linked_data_n_o,

  // TMU overflow
  output logic                          evt_ovf_o,
  output id_t                           evt_ovf_id_o,

  // Cut-and-drain fabrication
  input  logic                          fab_all_req_i,
  output logic                          fab_b_valid_o,
  output id_t                           fab_b_id_o,

  // Budgets
  input  hs_cnt_t                       budget_wlast_bvld_i,
  input  hs_cnt_t                       budget_bvld_brdy_i,
  input  hs_cnt_t                       budget_w_liveness_i,

  // Stage 4: Shared counters
  input  hs_cnt_t                       w_liveness_q_i,
  output hs_cnt_t                       w_liveness_n_o,
  input  logic [8:0]                    w_beat_cnt_q_i,
  output logic [8:0]                    w_beat_cnt_n_o,

  output logic                          timeout_stage4_o,
  output id_t                           timeout_id_stage4_o,
  output logic                          reset_stage4_o,
  output logic                          timeout_stage5_o,
  output logic                          timeout_stage6_o,
  output id_t                           timeout_id_stage5_o,
  output logic                          reset_stage5_o,
  output id_t                           timeout_id_stage6_o
);

  logic [HtCapacity-1:0] match_aw_oh, match_b_oh, ht_free_oh;
  logic [MaxWrTxns-1:0]  ld_free_oh;
  logic [HtCapacity-1:0] bid_match_oh;
  logic [HtCapacity-1:0] active_ht_oh;

  ht_idx_t match_aw_idx, match_b_idx, ht_free_idx;
  ld_idx_t ld_free_idx;
  logic aw_id_match, b_id_match, ht_free_valid, ld_free_valid;

  generate
    for (genvar i = 0; i < HtCapacity; i++) begin : gen_ht_match
      assign match_aw_oh[i]  = !head_tail_q_i[i].free &&
                               (head_tail_q_i[i].id == awid_q_i) &&
                               aw_hs_i;
      assign match_b_oh[i]   = !head_tail_q_i[i].free &&
                               (head_tail_q_i[i].id == bid_i) &&
                               b_hs_i;
      assign ht_free_oh[i]   = head_tail_q_i[i].free;
      assign active_ht_oh[i] = !head_tail_q_i[i].free;
      assign bid_match_oh[i] = !head_tail_q_i[i].free &&
                               (head_tail_q_i[i].id == bid_i);
    end

    for (genvar i = 0; i < MaxWrTxns; i++) begin : gen_ld_free
      assign ld_free_oh[i] = linked_data_q_i[i].free;
    end
  endgenerate

  assign aw_id_match   = |match_aw_oh;
  assign b_id_match    = |match_b_oh;
  assign ht_free_valid = |ht_free_oh;
  assign ld_free_valid = |ld_free_oh;

  onehot_to_bin #(
    .ONEHOT_WIDTH(HtCapacity)
  ) i_bin_aw (
    .onehot(match_aw_oh),
    .bin(match_aw_idx)
  );

  onehot_to_bin #(
    .ONEHOT_WIDTH(HtCapacity)
  ) i_bin_b (
    .onehot(match_b_oh),
    .bin(match_b_idx)
  );

  lzc #(
    .WIDTH(HtCapacity),
    .MODE(0)
  ) i_ff_ht (
    .in_i(ht_free_oh),
    .cnt_o(ht_free_idx),
    .empty_o()
  );

  lzc #(
    .WIDTH(MaxWrTxns),
    .MODE(0)
  ) i_ff_ld (
    .in_i(ld_free_oh),
    .cnt_o(ld_free_idx),
    .empty_o()
  );

  // Fabrication Logic: only emit B for transactions whose W phase is complete (WRITE_RESPONSE)
  logic any_id_nonempty;
  ht_idx_t pick_idx;
  id_t pick_bid;

  always_comb begin
    any_id_nonempty = 1'b0;
    pick_idx        = '0;
    pick_bid        = '0;
    if (fab_all_req_i) begin
      for (int i = 0; i < HtCapacity; i++) begin
        if (!head_tail_q_i[i].free &&
            !linked_data_q_i[head_tail_q_i[i].head].free &&
            (linked_data_q_i[head_tail_q_i[i].head].write_state == WRITE_RESPONSE)) begin
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
  logic [8:0] expected_beats;
  ld_idx_t next_head, head_idx, eff_active_idx;
  logic any_w_active;

  always_comb begin : proc_wr_queue
    head_tail_n_o      = head_tail_q_i;
    linked_data_n_o    = linked_data_q_i;
    w_fifo_n_o         = w_fifo_q_i;
    wr_ptr_n_o         = wr_ptr_q_i;
    rd_ptr_n_o         = rd_ptr_q_i;
    fifo_full_n_o      = fifo_full_q_i;
    fifo_empty_n_o     = fifo_empty_q_i;
    w_liveness_n_o     = w_liveness_q_i;
    w_beat_cnt_n_o     = w_beat_cnt_q_i;

    reset_req_o        = 1'b0;
    proto_err_o        = 1'b0;
    evt_ovf_o          = 1'b0;
    evt_ovf_id_o       = '0;
    abort_id_o         = '0;

    timeout_stage4_o    = 1'b0;
    timeout_id_stage4_o = '0;
    reset_stage4_o      = 1'b0;
    timeout_stage5_o    = 1'b0;
    timeout_id_stage5_o = '0;
    reset_stage5_o      = 1'b0;
    timeout_stage6_o    = 1'b0;
    timeout_id_stage6_o = '0;

    expected_beats     = '0;
    next_head          = '0;
    head_idx           = '0;

    any_w_active = !fifo_empty_q_i &&
                   !linked_data_q_i[active_idx_i].free &&
                   (linked_data_q_i[active_idx_i].write_state == WRITE_DATA);

    resources_full = (!ld_free_valid) ||
                     (!aw_id_match && !ht_free_valid) ||
                     fifo_full_q_i;

    if (!fab_all_req_i) begin
      if (any_w_active) begin
        if (w_liveness_q_i >= budget_w_liveness_i) begin
          timeout_stage4_o    = 1'b1;
          timeout_id_stage4_o = head_tail_q_i[linked_data_q_i[active_idx_i].ht_idx].id;
          reset_stage4_o      = w_valid_i && !w_ready_i;
        end

        if ((w_liveness_q_i < budget_w_liveness_i) && prescaled_en_i && !w_hs_i) begin
          w_liveness_n_o = w_liveness_q_i + 1'b1;
        end
      end

      if (w_hs_i || !any_w_active) begin
        w_liveness_n_o = '0;
      end

      // Stage 5 & 6 - Priority (Disarm > Timeout > Arm)
      for (int k = 0; k < HtCapacity; k++) begin
        if (active_ht_oh[k]) begin
          head_idx = head_tail_q_i[k].head;

          // Stage 5: Arm when HEAD enters WRITE_RESPONSE (on WLAST)
          if (!linked_data_q_i[head_idx].free &&
              linked_data_q_i[head_idx].write_state == WRITE_RESPONSE &&
              !head_tail_q_i[k].waiting_bvalid) begin
            head_tail_n_o[k].waiting_bvalid   = 1'b1;
            head_tail_n_o[k].cnt_wlast_bvalid = '0;
          end

          if (head_tail_q_i[k].waiting_bvalid &&
              (head_tail_q_i[k].cnt_wlast_bvalid >= budget_wlast_bvld_i)) begin
            timeout_stage5_o    = 1'b1;
            reset_stage5_o      = 1'b1;
            timeout_id_stage5_o = head_tail_q_i[k].id;
          end

          if (head_tail_q_i[k].waiting_bvalid && prescaled_en_i) begin
            if (head_tail_q_i[k].cnt_wlast_bvalid < budget_wlast_bvld_i) begin
              head_tail_n_o[k].cnt_wlast_bvalid = head_tail_q_i[k].cnt_wlast_bvalid + 1'b1;
            end
          end

          if (b_valid_i && bid_match_oh[k]) begin
            head_tail_n_o[k].waiting_bvalid   = 1'b0;
            head_tail_n_o[k].cnt_wlast_bvalid = '0;
          end

          // Stage 6: BVALID->BREADY
          if (b_valid_i && !b_ready_i && bid_match_oh[k] &&
              !head_tail_q_i[k].waiting_bready) begin
            head_tail_n_o[k].waiting_bready    = 1'b1;
            head_tail_n_o[k].cnt_bvalid_bready = '0;
          end

          if (head_tail_q_i[k].waiting_bready &&
              (head_tail_q_i[k].cnt_bvalid_bready >= budget_bvld_brdy_i)) begin
            timeout_stage6_o    = 1'b1;
            timeout_id_stage6_o = head_tail_q_i[k].id;
          end

          if (head_tail_q_i[k].waiting_bready && prescaled_en_i) begin
            if (head_tail_q_i[k].cnt_bvalid_bready < budget_bvld_brdy_i) begin
              head_tail_n_o[k].cnt_bvalid_bready = head_tail_q_i[k].cnt_bvalid_bready + 1'b1;
            end
          end

          if (b_hs_i && bid_match_oh[k]) begin
            head_tail_n_o[k].waiting_bready    = 1'b0;
            head_tail_n_o[k].cnt_bvalid_bready = '0;
          end
        end
      end
    end

    // AW Handshake - Transaction Enqueue (also active during cut to drain upstream AW requests)
    if (aw_hs_i) begin : proc_txn_enqueue
      if (resources_full) begin
        if (!fab_all_req_i) begin
          evt_ovf_o    = 1'b1;
          evt_ovf_id_o = awid_q_i;
        end
      end else begin
        w_fifo_n_o[wr_ptr_q_i] = ld_free_idx;
        wr_ptr_n_o             = wr_ptr_q_i + 1'b1;
        fifo_empty_n_o         = 1'b0;
        fifo_full_n_o          = (wr_ptr_n_o == rd_ptr_q_i);
        expected_beats         = awlen_q_i + 1'b1;

        if (!aw_id_match) begin
          head_tail_n_o[ht_free_idx] = '{
            id:                awid_q_i,
            head:              ld_free_idx,
            tail:              ld_free_idx,
            free:              1'b0,
            cnt_wlast_bvalid:  '0,
            cnt_bvalid_bready: '0,
            waiting_bvalid:    1'b0,
            waiting_bready:    1'b0
          };
        end else begin
          linked_data_n_o[head_tail_q_i[match_aw_idx].tail].next = ld_free_idx;
          head_tail_n_o[match_aw_idx].tail                       = ld_free_idx;
        end

        linked_data_n_o[ld_free_idx] = '{
          write_state:    WRITE_ADDRESS,
          expected_beats: expected_beats,
          ht_idx:         aw_id_match ? match_aw_idx : ht_free_idx,
          next:           '0,
          free:           1'b0
        };
      end
    end

    // Resolve effective active W-FIFO head when AW and W handshake in the same cycle
    eff_active_idx = (fifo_empty_q_i && aw_hs_i && !resources_full)
                     ? ld_free_idx : active_idx_i;

    // W HANDLING - State Transitions (continues during cut to drain upstream W beats)
    if (w_hs_i && !fifo_empty_n_o) begin
      if (!linked_data_n_o[eff_active_idx].free) begin
        w_beat_cnt_n_o = w_beat_cnt_q_i + 9'd1;

        case (linked_data_n_o[eff_active_idx].write_state)
          WRITE_ADDRESS: begin
            if (wlast_q_i) begin
              if (!fab_all_req_i && (9'd1 != linked_data_n_o[eff_active_idx].expected_beats)) begin
                proto_err_o = 1'b1;
                reset_req_o = 1'b1;
                abort_id_o  = head_tail_n_o[linked_data_n_o[eff_active_idx].ht_idx].id;
              end else begin
                linked_data_n_o[eff_active_idx].write_state = WRITE_RESPONSE;
                rd_ptr_n_o     = rd_ptr_q_i + 1'b1;
                fifo_full_n_o  = 1'b0;
                fifo_empty_n_o = (rd_ptr_n_o == wr_ptr_n_o);
                w_beat_cnt_n_o = 9'd0;
              end
            end else begin
              if (!fab_all_req_i && (9'd1 >= linked_data_n_o[eff_active_idx].expected_beats)) begin
                proto_err_o = 1'b1;
                reset_req_o = 1'b1;
                abort_id_o  = head_tail_n_o[linked_data_n_o[eff_active_idx].ht_idx].id;
              end else begin
                linked_data_n_o[eff_active_idx].write_state = WRITE_DATA;
              end
            end
          end

          WRITE_DATA: begin
            if (wlast_q_i) begin
              if (!fab_all_req_i &&
                  (w_beat_cnt_n_o != linked_data_n_o[eff_active_idx].expected_beats)) begin
                proto_err_o = 1'b1;
                reset_req_o = 1'b1;
                abort_id_o  = head_tail_n_o[linked_data_n_o[eff_active_idx].ht_idx].id;
              end else begin
                linked_data_n_o[eff_active_idx].write_state = WRITE_RESPONSE;
                rd_ptr_n_o     = rd_ptr_q_i + 1'b1;
                fifo_full_n_o  = 1'b0;
                fifo_empty_n_o = (rd_ptr_n_o == wr_ptr_n_o);
                w_beat_cnt_n_o = 9'd0;
              end
            end else begin
              if (!fab_all_req_i &&
                  (w_beat_cnt_n_o >= linked_data_n_o[eff_active_idx].expected_beats)) begin
                proto_err_o = 1'b1;
                reset_req_o = 1'b1;
                abort_id_o  = head_tail_n_o[linked_data_n_o[eff_active_idx].ht_idx].id;
              end
            end
          end

          default: ;
        endcase
      end
    end

    // DEQUEUE on normal B handshake (when not fabricating)
    if (b_hs_i && !fab_all_req_i) begin
      if (!b_id_match ||
          (linked_data_n_o[head_tail_q_i[match_b_idx].head].write_state != WRITE_RESPONSE)) begin
        proto_err_o = 1'b1;
        reset_req_o = 1'b1;
        abort_id_o  = bid_i;
      end else begin
        linked_data_n_o[head_tail_q_i[match_b_idx].head]      = '0;
        linked_data_n_o[head_tail_q_i[match_b_idx].head].free = 1'b1;

        if (head_tail_q_i[match_b_idx].head == head_tail_q_i[match_b_idx].tail) begin
          if (aw_hs_i && !resources_full && aw_id_match && (match_aw_idx == match_b_idx)) begin
            head_tail_n_o[match_b_idx].head = ld_free_idx;
          end else begin
            head_tail_n_o[match_b_idx] = '{free: 1'b1, default: '0};
          end
        end else begin
          next_head = linked_data_q_i[head_tail_q_i[match_b_idx].head].next;
          head_tail_n_o[match_b_idx].head = next_head;
        end
      end
    end

    // FABRICATION: drain pending WRITE_RESPONSE transactions as SLVERR
    if (fab_all_req_i && fab_b_valid_o && b_ready_i) begin
      linked_data_n_o[head_tail_q_i[pick_idx].head]      = '0;
      linked_data_n_o[head_tail_q_i[pick_idx].head].free = 1'b1;

      if (head_tail_q_i[pick_idx].head == head_tail_q_i[pick_idx].tail) begin
        if (aw_hs_i && !resources_full && aw_id_match && (match_aw_idx == pick_idx)) begin
          head_tail_n_o[pick_idx].head = ld_free_idx;
        end else begin
          head_tail_n_o[pick_idx] = '{free: 1'b1, default: '0};
        end
      end else begin
        head_tail_n_o[pick_idx].head = linked_data_q_i[head_tail_q_i[pick_idx].head].next;
      end
    end

    // Clear all tables on external reset acknowledgment
    if (reset_clear_i) begin
      for (int m = 0; m < MaxWrTxns; m++) begin
        linked_data_n_o[m] = '{default: '0, free: 1'b1};
      end
      for (int n = 0; n < HtCapacity; n++) begin
        head_tail_n_o[n] = '{free: 1'b1, default: '0};
      end
      wr_ptr_n_o     = '0;
      rd_ptr_n_o     = '0;
      fifo_empty_n_o = 1'b1;
      fifo_full_n_o  = 1'b0;
      w_fifo_n_o     = '0;
      w_liveness_n_o = '0;
      w_beat_cnt_n_o = '0;
    end
  end

endmodule