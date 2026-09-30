// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Chaoqun Liang <chaoqun.liang@unibo.it>

module tmu_rd_inflight
  import axi_tmu_pkg::*;
#(
  parameter int unsigned MaxRdTxns     = 1,
  parameter int unsigned HtCapacity    = 1,
  parameter type linked_data_t         = logic,
  parameter type head_tail_t           = logic,
  parameter type ht_idx_t              = logic,
  parameter type ld_idx_t              = logic,
  parameter type id_t                  = logic,
  parameter type hs_cnt_t              = logic
)(
  input  logic                          prescaled_en_i,
  input  logic                          reset_clear_i,

  input  hs_cnt_t                       budget_arhs_rfirst_i,
  input  hs_cnt_t                       budget_rvld_rrdy_i,
  input  hs_cnt_t                       budget_r_liveness_i,

  input  logic                          ar_hs_i,
  input  id_t                           arid_i,
  input  axi_pkg::len_t                 arlen_i,

  input  logic                          r_hs_i,
  input  logic                          r_valid_i,
  input  logic                          r_ready_i,
  input  logic                          rlast_i,
  input  id_t                           rid_i,

  output logic                          reset_req_o,
  output id_t                           abort_id_o,
  output logic                          proto_err_o,

  output logic                          timeout_stage2_o,
  output logic                          timeout_stage3_o,
  output logic                          timeout_stage4_o,
  output logic                          reset_stage2_o,
  output logic                          reset_stage4_o,
  output id_t                           timeout_id_stage2_o,
  output id_t                           timeout_id_stage3_o,
  output id_t                           timeout_id_stage4_o,

  input  head_tail_t     [HtCapacity-1:0]  head_tail_q_i,
  output head_tail_t     [HtCapacity-1:0]  head_tail_n_o,
  input  linked_data_t   [MaxRdTxns-1:0]   linked_data_q_i,
  output linked_data_t   [MaxRdTxns-1:0]   linked_data_n_o,

  output logic                          evt_ovf_o,
  output id_t                           evt_ovf_id_o,

  input  logic                          fab_all_req_i,
  output logic                          fab_r_valid_o,
  output id_t                           fab_r_id_o,
  output logic                          fab_r_last_o
);

  logic [HtCapacity-1:0]  match_ar_oh, match_r_oh, ht_free_oh;
  logic [MaxRdTxns-1:0]   ld_free_oh;
  logic [HtCapacity-1:0]  rid_match_oh;

  ht_idx_t                match_ar_idx, match_r_idx, ht_free_idx;
  ld_idx_t                ld_free_idx;
  logic                   ar_id_match, r_id_match, ht_free_valid, ld_free_valid;

  generate
    for (genvar i = 0; i < HtCapacity; i++) begin : g_ht
      assign match_ar_oh[i]  = !head_tail_q_i[i].free && (head_tail_q_i[i].id == arid_i) && ar_hs_i;
      assign match_r_oh[i]   = !head_tail_q_i[i].free && (head_tail_q_i[i].id == rid_i) && r_hs_i;
      assign ht_free_oh[i]   = head_tail_q_i[i].free;
      assign rid_match_oh[i] = !head_tail_q_i[i].free && (head_tail_q_i[i].id == rid_i);
    end
    for (genvar i = 0; i < MaxRdTxns; i++) begin : g_ld
      assign ld_free_oh[i]   = linked_data_q_i[i].free;
    end
  endgenerate

  assign ar_id_match   = |match_ar_oh;
  assign r_id_match    = |match_r_oh;
  assign ht_free_valid = |ht_free_oh;
  assign ld_free_valid = |ld_free_oh;

  onehot_to_bin #(.ONEHOT_WIDTH(HtCapacity)) i_bin_ar (.onehot(match_ar_oh), .bin(match_ar_idx));
  onehot_to_bin #(.ONEHOT_WIDTH(HtCapacity)) i_bin_r  (.onehot(match_r_oh),  .bin(match_r_idx));
  lzc #(.WIDTH(HtCapacity), .MODE(0)) i_ff_ht (.in_i(ht_free_oh), .cnt_o(ht_free_idx), .empty_o());
  lzc #(.WIDTH(MaxRdTxns),  .MODE(0)) i_ff_ld (.in_i(ld_free_oh), .cnt_o(ld_free_idx), .empty_o());

  //----------------------------------------------------------------------------
  // Multi-beat Fabrication Logic
  //----------------------------------------------------------------------------
  logic    any_rid_nonempty;
  ht_idx_t pick_ridx;
  id_t     pick_rid;
  ld_idx_t pick_head_ld;

  always_comb begin
    any_rid_nonempty = 1'b0;
    pick_ridx        = '0;
    pick_rid         = '0;
    pick_head_ld     = '0;
    if (fab_all_req_i) begin
      for (int j = 0; j < HtCapacity; j++) begin
        if (!head_tail_q_i[j].free) begin
          any_rid_nonempty = 1'b1;
          pick_ridx        = ht_idx_t'(j);
          pick_rid         = head_tail_q_i[j].id;
          pick_head_ld     = head_tail_q_i[j].head;
          break;
        end
      end
    end
  end

  assign fab_r_valid_o = any_rid_nonempty;
  assign fab_r_id_o    = pick_rid;
  assign fab_r_last_o  = any_rid_nonempty &&
                         ((head_tail_q_i[pick_ridx].r_beat_cnt + 9'd1) >=
                          linked_data_q_i[pick_head_ld].expected_beats);

  logic       resources_full;
  logic [8:0] expected_beats;
  ld_idx_t    head_k;
  logic       is_first_r;
  ld_idx_t    fab_head;
  ld_idx_t    head_r_idx;

  always_comb begin
    head_tail_n_o   = head_tail_q_i;
    linked_data_n_o = linked_data_q_i;

    fab_head            = '0;
    head_r_idx          = '0;
    head_k              = '0;
    is_first_r          = 1'b0;
    reset_req_o         = 1'b0;
    abort_id_o          = '0;
    proto_err_o         = 1'b0;
    evt_ovf_o           = 1'b0;
    evt_ovf_id_o        = '0;
    expected_beats      = '0;

    timeout_stage2_o    = 1'b0;
    timeout_stage3_o    = 1'b0;
    timeout_stage4_o    = 1'b0;
    timeout_id_stage2_o = '0;
    timeout_id_stage3_o = '0;
    timeout_id_stage4_o = '0;
    reset_stage2_o      = 1'b0;
    reset_stage4_o      = 1'b0;

    resources_full = (!ld_free_valid) || (!ar_id_match && !ht_free_valid);

    // AR_HS: Enqueue new transaction (also active during cut to drain upstream AR requests)
    if (ar_hs_i) begin
      if (resources_full) begin
        if (!fab_all_req_i) begin
          evt_ovf_o    = 1'b1;
          evt_ovf_id_o = arid_i;
        end
      end else begin
        expected_beats = arlen_i + 1'b1;
        if (!ar_id_match) begin
          head_tail_n_o[ht_free_idx] = '{
            id:              arid_i,
            head:            ld_free_idx,
            tail:            ld_free_idx,
            free:            1'b0,
            rfirst_arm:      1'b1,
            arhs_rfirst_cnt: '0,
            rvld_rrdy_cnt:   '0,
            r_liveness_cnt:  '0,
            r_beat_cnt:      '0
          };
        end else begin
          linked_data_n_o[head_tail_q_i[match_ar_idx].tail].next = ld_free_idx;
          head_tail_n_o[match_ar_idx].tail                       = ld_free_idx;
        end

        linked_data_n_o[ld_free_idx] = '{
          expected_beats: expected_beats,
          read_state:     READ_ADDRESS,
          next:           '0,
          free:           1'b0
        };
      end
    end

    // R_HS: Process normal read data (when not fabricating)
    if (r_hs_i && !fab_all_req_i) begin
      if (!r_id_match) begin
        proto_err_o = 1'b1;
        reset_req_o = 1'b1;
        abort_id_o  = rid_i;
      end else begin
        head_r_idx = head_tail_q_i[match_r_idx].head;
        is_first_r = (linked_data_q_i[head_r_idx].read_state == READ_ADDRESS);

        head_tail_n_o[match_r_idx].r_beat_cnt = head_tail_q_i[match_r_idx].r_beat_cnt + 9'd1;
        if (is_first_r) begin
          head_tail_n_o[match_r_idx].rfirst_arm      = 1'b0;
          head_tail_n_o[match_r_idx].arhs_rfirst_cnt = '0;
          head_tail_n_o[match_r_idx].rvld_rrdy_cnt   = '0;
          head_tail_n_o[match_r_idx].r_liveness_cnt  = '0;

          if (!rlast_i) begin
            linked_data_n_o[head_r_idx].read_state = READ_DATA;
          end
        end else begin
          head_tail_n_o[match_r_idx].r_liveness_cnt = '0;
        end

        if (rlast_i) begin
          if (head_tail_n_o[match_r_idx].r_beat_cnt !=
              linked_data_n_o[head_r_idx].expected_beats) begin
            proto_err_o = 1'b1;
            reset_req_o = 1'b1;
            abort_id_o  = head_tail_n_o[match_r_idx].id;
          end else begin
            linked_data_n_o[head_r_idx] = '{default: '0, free: 1'b1};

            if (head_tail_q_i[match_r_idx].head == head_tail_q_i[match_r_idx].tail) begin
              if (ar_hs_i && !resources_full && ar_id_match && (match_ar_idx == match_r_idx)) begin
                head_tail_n_o[match_r_idx].head            = ld_free_idx;
                head_tail_n_o[match_r_idx].rfirst_arm      = 1'b1;
                head_tail_n_o[match_r_idx].arhs_rfirst_cnt = '0;
                head_tail_n_o[match_r_idx].rvld_rrdy_cnt   = '0;
                head_tail_n_o[match_r_idx].r_liveness_cnt  = '0;
                head_tail_n_o[match_r_idx].r_beat_cnt      = '0;
              end else begin
                head_tail_n_o[match_r_idx] = '{free: 1'b1, default: '0};
              end
            end else begin
              head_tail_n_o[match_r_idx].head            = linked_data_q_i[head_r_idx].next;
              head_tail_n_o[match_r_idx].rfirst_arm      = 1'b1;
              head_tail_n_o[match_r_idx].arhs_rfirst_cnt = '0;
              head_tail_n_o[match_r_idx].rvld_rrdy_cnt   = '0;
              head_tail_n_o[match_r_idx].r_liveness_cnt  = '0;
              head_tail_n_o[match_r_idx].r_beat_cnt      = '0;
            end
          end
        end else begin
          if (head_tail_n_o[match_r_idx].r_beat_cnt >=
              linked_data_n_o[head_r_idx].expected_beats) begin
            proto_err_o = 1'b1;
            reset_req_o = 1'b1;
            abort_id_o  = head_tail_n_o[match_r_idx].id;
          end
        end
      end
    end

    // COUNTER UPDATES (disabled during fabrication)
    if (!fab_all_req_i) begin
      for (int k = 0; k < HtCapacity; k++) begin
        if (!head_tail_q_i[k].free) begin
          head_k = head_tail_q_i[k].head;

          // Stage 2: ARHS->RFIRST
          if (head_tail_q_i[k].rfirst_arm &&
              linked_data_q_i[head_k].read_state == READ_ADDRESS) begin
            if (head_tail_q_i[k].arhs_rfirst_cnt >= budget_arhs_rfirst_i) begin
              timeout_stage2_o    = 1'b1;
              reset_stage2_o      = 1'b1;
              timeout_id_stage2_o = head_tail_q_i[k].id;
            end

            if ((head_tail_q_i[k].arhs_rfirst_cnt < budget_arhs_rfirst_i) &&
                prescaled_en_i && !(r_valid_i && rid_match_oh[k])) begin
              head_tail_n_o[k].arhs_rfirst_cnt = head_tail_q_i[k].arhs_rfirst_cnt + 1'b1;
            end
          end

          // Stage 3: RVLD->RRDY (first beat)
          if (head_tail_q_i[k].rfirst_arm &&
              linked_data_q_i[head_k].read_state == READ_ADDRESS) begin
            if (head_tail_q_i[k].rvld_rrdy_cnt >= budget_rvld_rrdy_i) begin
              timeout_stage3_o    = 1'b1;
              timeout_id_stage3_o = head_tail_q_i[k].id;
            end

            if ((head_tail_q_i[k].rvld_rrdy_cnt < budget_rvld_rrdy_i) &&
                prescaled_en_i && r_valid_i && !r_ready_i && rid_match_oh[k]) begin
              head_tail_n_o[k].rvld_rrdy_cnt = head_tail_q_i[k].rvld_rrdy_cnt + 1'b1;
            end
          end

          // Stage 4: R DATA LIVENESS
          if (linked_data_q_i[head_k].read_state == READ_DATA) begin
            if (head_tail_q_i[k].r_liveness_cnt >= budget_r_liveness_i) begin
              timeout_stage4_o    = 1'b1;
              reset_stage4_o      = 1'b1;
              timeout_id_stage4_o = head_tail_q_i[k].id;
            end

            if ((head_tail_q_i[k].r_liveness_cnt < budget_r_liveness_i) &&
                prescaled_en_i && !(r_hs_i && rid_match_oh[k])) begin
              head_tail_n_o[k].r_liveness_cnt = head_tail_q_i[k].r_liveness_cnt + 1'b1;
            end
          end
        end
      end
    end

    // FABRICATION: drain remaining beats of each pending read burst with SLVERR
    if (fab_all_req_i && fab_r_valid_o && r_ready_i) begin
      fab_head = head_tail_q_i[pick_ridx].head;
      if (fab_r_last_o) begin
        linked_data_n_o[fab_head] = '{default: '0, free: 1'b1};
        if (head_tail_q_i[pick_ridx].head == head_tail_q_i[pick_ridx].tail) begin
          if (ar_hs_i && !resources_full && ar_id_match && (match_ar_idx == pick_ridx)) begin
            head_tail_n_o[pick_ridx].head       = ld_free_idx;
            head_tail_n_o[pick_ridx].r_beat_cnt = '0;
          end else begin
            head_tail_n_o[pick_ridx] = '{free: 1'b1, default: '0};
          end
        end else begin
          head_tail_n_o[pick_ridx].head       = linked_data_q_i[fab_head].next;
          head_tail_n_o[pick_ridx].r_beat_cnt = '0;
        end
      end else begin
        head_tail_n_o[pick_ridx].r_beat_cnt = head_tail_q_i[pick_ridx].r_beat_cnt + 9'd1;
      end
    end

    // Clear all tables on external reset acknowledgment
    if (reset_clear_i) begin
      for (int m = 0; m < MaxRdTxns; m++) begin
        linked_data_n_o[m] = '{default: '0, free: 1'b1};
      end
      for (int n = 0; n < HtCapacity; n++) begin
        head_tail_n_o[n] = '{free: 1'b1, default: '0};
      end
    end
  end

  `ifndef SYNTHESIS
  initial begin
    assert (MaxRdTxns > 0)
      else $fatal(1, "[tmu_rd_inflight] MaxRdTxns must be > 0");
    assert (HtCapacity > 0)
      else $fatal(1, "[tmu_rd_inflight] HtCapacity must be > 0");
  end
  `endif

endmodule