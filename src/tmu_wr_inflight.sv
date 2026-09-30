// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Chaoqun Liang <chaoqun.liang@unibo.it>

// Channel-Level Tracking (CLT) Write Inflight Manager:
// 1. W Channel Liveness (Shared, Channel-Level):
//    - Armed whenever W-FIFO is non-empty (WRITE_ADDRESS or WRITE_DATA)
//    - Resets on any W handshake (w_hs_i)
// 2. Shared W Beat Counter (w_beat_cnt_q_i):
//    - Validates WLAST against expected_beats (AWLEN + 1)
// 3. B Response Timeout (Per-ID Head Only):
//    - Tracks head transaction in WRITE_RESPONSE state (WLAST -> B_HS)

module tmu_wr_inflight
  import axi_tmu_pkg::*;
#(
  parameter int unsigned MaxWrTxns  = 1,
  parameter int unsigned HtCapacity = 1,
  parameter int unsigned PtrWidth   = $clog2(MaxWrTxns),
  parameter type linked_data_t      = logic,
  parameter type head_tail_t        = logic,
  parameter type ht_idx_t           = logic,
  parameter type ld_idx_t           = logic,
  parameter type id_t               = logic,
  parameter type hs_cnt_t           = logic
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

  // Cycle-accurate AXI signals
  input  logic                          aw_hs_i,
  input  id_t                           awid_q_i,
  input  axi_pkg::len_t                 awlen_q_i,

  input  logic                          w_hs_i,
  input  logic                          w_valid_i,
  input  logic                          w_ready_i,
  input  logic                          wlast_q_i,

  input  logic                          b_hs_i,
  input  logic                          b_valid_i,
  input  logic                          b_ready_i,
  input  id_t                           bid_i,

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

  // CLT Budgets
  input  hs_cnt_t                       budget_w_liveness_i,
  input  hs_cnt_t                       budget_b_timeout_i,

  // Shared W-channel counters
  input  hs_cnt_t                       w_liveness_q_i,
  output hs_cnt_t                       w_liveness_n_o,
  input  logic [8:0]                    w_beat_cnt_q_i,
  output logic [8:0]                    w_beat_cnt_n_o,

  // Timeout outputs
  output logic                          timeout_w_o,
  output logic                          reset_w_o,
  output logic                          timeout_b_o,
  output logic                          reset_b_o,
  output id_t                           id_w_o,
  output id_t                           id_b_o
);

  logic [HtCapacity-1:0] match_aw_oh, match_b_oh, ht_free_oh;
  logic [MaxWrTxns-1:0]  ld_free_oh;
  logic [HtCapacity-1:0] bid_match_oh;

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

  onehot_to_bin #(.ONEHOT_WIDTH(HtCapacity)) i_bin_aw (.onehot(match_aw_oh), .bin(match_aw_idx));
  onehot_to_bin #(.ONEHOT_WIDTH(HtCapacity)) i_bin_b  (.onehot(match_b_oh),  .bin(match_b_idx));
  lzc #(.WIDTH(HtCapacity), .MODE(0)) i_ff_ht (.in_i(ht_free_oh), .cnt_o(ht_free_idx), .empty_o());
  lzc #(.WIDTH(MaxWrTxns),  .MODE(0)) i_ff_ld (.in_i(ld_free_oh), .cnt_o(ld_free_idx), .empty_o());

  // Fabrication Logic: only emit B for transactions whose W phase is complete (WRITE_RESPONSE)
  logic    any_id_nonempty;
  ht_idx_t pick_idx;
  id_t     pick_bid;

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

  logic       resources_full;
  logic [8:0] expected_beats;
  ld_idx_t    next_head, eff_active_idx;
  ht_idx_t    active_ht_idx;
  logic       any_w_active;

  always_comb begin : proc_wr_queue
    head_tail_n_o  = head_tail_q_i;
    linked_data_n_o= linked_data_q_i;
    w_fifo_n_o     = w_fifo_q_i;
    wr_ptr_n_o     = wr_ptr_q_i;
    rd_ptr_n_o     = rd_ptr_q_i;
    fifo_full_n_o  = fifo_full_q_i;
    fifo_empty_n_o = fifo_empty_q_i;
    w_liveness_n_o = w_liveness_q_i;
    w_beat_cnt_n_o = w_beat_cnt_q_i;

    reset_req_o    = 1'b0;
    proto_err_o    = 1'b0;
    evt_ovf_o      = 1'b0;
    evt_ovf_id_o   = '0;
    abort_id_o     = '0;

    timeout_w_o    = 1'b0;
    reset_w_o      = 1'b0;
    timeout_b_o    = 1'b0;
    reset_b_o      = 1'b0;
    id_b_o         = '0;
    id_w_o         = '0;

    expected_beats = '0;
    next_head      = '0;
    active_ht_idx  = '0;

    // Coalesced W-Channel Liveness: active whenever W-FIFO has an owner waiting for W beats
    any_w_active = !fifo_empty_q_i &&
                   !linked_data_q_i[active_idx_i].free &&
                   ((linked_data_q_i[active_idx_i].write_state == WRITE_ADDRESS) ||
                    (linked_data_q_i[active_idx_i].write_state == WRITE_DATA));

    resources_full = (!ld_free_valid) ||
                     (!aw_id_match && !ht_free_valid) ||
                     fifo_full_q_i;

    if (!fab_all_req_i) begin
      // 1. Coalesced W Channel Liveness
      if (any_w_active) begin
        if (w_liveness_q_i >= budget_w_liveness_i) begin
          timeout_w_o = 1'b1;
          id_w_o      = head_tail_q_i[linked_data_q_i[active_idx_i].ht_idx].id;
          reset_w_o   = w_valid_i && !w_ready_i;
        end

        if ((w_liveness_q_i < budget_w_liveness_i) && prescaled_en_i && !w_hs_i) begin
          w_liveness_n_o = w_liveness_q_i + 1'b1;
        end
      end

      if (w_hs_i || !any_w_active) begin
        w_liveness_n_o = '0;
      end

      // 2. Coalesced B Response Timeout (WLAST -> B_HS per ID head)
      for (int i = 0; i < HtCapacity; i++) begin
        if (!head_tail_q_i[i].free && head_tail_q_i[i].expecting_b) begin
          if (head_tail_q_i[i].b_timeout_counter >= budget_b_timeout_i) begin
            timeout_b_o = 1'b1;
            id_b_o      = head_tail_q_i[i].id;
            reset_b_o   = !(b_valid_i && !b_ready_i && bid_match_oh[i]);
          end

          if (prescaled_en_i && !(b_hs_i && bid_match_oh[i]) &&
              (head_tail_q_i[i].b_timeout_counter < budget_b_timeout_i)) begin
            head_tail_n_o[i].b_timeout_counter = head_tail_q_i[i].b_timeout_counter + 1'b1;
          end
        end
      end
    end

    // AW Handshake - Transaction Enqueue
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
            expecting_b:       1'b0,
            b_timeout_counter: '0
          };
        end else begin
          linked_data_n_o[head_tail_q_i[match_aw_idx].tail].next = ld_free_idx;
          head_tail_n_o[match_aw_idx].tail                       = ld_free_idx;
        end

        linked_data_n_o[ld_free_idx] = '{
          expected_beats: expected_beats,
          write_state:    WRITE_ADDRESS,
          ht_idx:         aw_id_match ? match_aw_idx : ht_free_idx,
          next:           '0,
          free:           1'b0
        };
      end
    end

    // Resolve effective active W-FIFO head when AW and W handshake in the same cycle
    eff_active_idx = (fifo_empty_q_i && aw_hs_i && !resources_full)
                     ? ld_free_idx : active_idx_i;

    // W HANDLING - State Transitions & Beat Verification
    if (w_hs_i && !fifo_empty_n_o) begin
      if (!linked_data_n_o[eff_active_idx].free) begin
        w_beat_cnt_n_o = w_beat_cnt_q_i + 9'd1;
        active_ht_idx  = linked_data_n_o[eff_active_idx].ht_idx;

        case (linked_data_n_o[eff_active_idx].write_state)
          WRITE_ADDRESS: begin
            if (wlast_q_i) begin
              if (!fab_all_req_i && (9'd1 != linked_data_n_o[eff_active_idx].expected_beats)) begin
                proto_err_o = 1'b1;
                reset_req_o = 1'b1;
                abort_id_o  = head_tail_n_o[active_ht_idx].id;
              end else begin
                linked_data_n_o[eff_active_idx].write_state = WRITE_RESPONSE;
                rd_ptr_n_o     = rd_ptr_q_i + 1'b1;
                fifo_full_n_o  = 1'b0;
                fifo_empty_n_o = (rd_ptr_n_o == wr_ptr_n_o);
                w_beat_cnt_n_o = 9'd0;

                if (head_tail_n_o[active_ht_idx].head == eff_active_idx) begin
                  head_tail_n_o[active_ht_idx].expecting_b       = 1'b1;
                  head_tail_n_o[active_ht_idx].b_timeout_counter = '0;
                end
              end
            end else begin
              if (!fab_all_req_i && (9'd1 >= linked_data_n_o[eff_active_idx].expected_beats)) begin
                proto_err_o = 1'b1;
                reset_req_o = 1'b1;
                abort_id_o  = head_tail_n_o[active_ht_idx].id;
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
                abort_id_o  = head_tail_n_o[active_ht_idx].id;
              end else begin
                linked_data_n_o[eff_active_idx].write_state = WRITE_RESPONSE;
                rd_ptr_n_o     = rd_ptr_q_i + 1'b1;
                fifo_full_n_o  = 1'b0;
                fifo_empty_n_o = (rd_ptr_n_o == wr_ptr_n_o);
                w_beat_cnt_n_o = 9'd0;

                if (head_tail_n_o[active_ht_idx].head == eff_active_idx) begin
                  head_tail_n_o[active_ht_idx].expecting_b       = 1'b1;
                  head_tail_n_o[active_ht_idx].b_timeout_counter = '0;
                end
              end
            end else begin
              if (!fab_all_req_i &&
                  (w_beat_cnt_n_o >= linked_data_n_o[eff_active_idx].expected_beats)) begin
                proto_err_o = 1'b1;
                reset_req_o = 1'b1;
                abort_id_o  = head_tail_n_o[active_ht_idx].id;
              end
            end
          end

          default: ;
        endcase
      end
    end

    // B Handshake - DEQUEUE
    if (b_hs_i && !fab_all_req_i) begin
      if (!b_id_match ||
          (linked_data_n_o[head_tail_q_i[match_b_idx].head].write_state != WRITE_RESPONSE)) begin
        proto_err_o = 1'b1;
        reset_req_o = 1'b1;
        abort_id_o  = bid_i;
      end else begin
        linked_data_n_o[head_tail_q_i[match_b_idx].head]      = '0;
        linked_data_n_o[head_tail_q_i[match_b_idx].head].free = 1'b1;

        head_tail_n_o[match_b_idx].expecting_b       = 1'b0;
        head_tail_n_o[match_b_idx].b_timeout_counter = '0;

        if (head_tail_q_i[match_b_idx].head == head_tail_q_i[match_b_idx].tail) begin
          if (aw_hs_i && !resources_full && aw_id_match && (match_aw_idx == match_b_idx)) begin
            head_tail_n_o[match_b_idx].head = ld_free_idx;
            if (linked_data_n_o[ld_free_idx].write_state == WRITE_RESPONSE) begin
              head_tail_n_o[match_b_idx].expecting_b = 1'b1;
            end
          end else begin
            head_tail_n_o[match_b_idx] = '{free: 1'b1, default: '0};
          end
        end else begin
          next_head = linked_data_q_i[head_tail_q_i[match_b_idx].head].next;
          head_tail_n_o[match_b_idx].head = next_head;

          if (linked_data_n_o[next_head].write_state == WRITE_RESPONSE) begin
            head_tail_n_o[match_b_idx].expecting_b       = 1'b1;
            head_tail_n_o[match_b_idx].b_timeout_counter = '0;
          end
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