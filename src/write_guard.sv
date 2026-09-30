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

  // AXI Write Channel Signals
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

  input  logic           prescaled_en_i,

  // CLT Budgets (3 timeout counters + 1 shared beat counter)
  input  hs_cnt_t        budget_avld_ardy_i,
  input  hs_cnt_t        budget_w_liveness_i,
  input  hs_cnt_t        budget_b_timeout_i,

  output logic           reset_req_o,
  output logic           timeout_o,
  output id_t            abort_id_o,

  output logic           evt_ovf_o,
  output id_t            evt_ovf_id_o,

  input  logic           fab_all_req_i,
  output logic           fab_b_valid_o,
  output id_t            fab_b_id_o,

  output logic                         fault_pulse_o,
  output axi_tmu_pkg::tmu_phase_t      fault_phase_o,
  output axi_tmu_pkg::tmu_fault_type_t fault_type_o
);

  localparam int HtCapacity          = (MaxUniqIds <= MaxWrTxns) ? MaxUniqIds : MaxWrTxns;
  localparam int unsigned HtIdxWidth = cf_math_pkg::idx_width(HtCapacity);
  localparam int unsigned LdIdxWidth = cf_math_pkg::idx_width(MaxWrTxns);
  localparam int unsigned PtrWidth   = (MaxWrTxns > 1) ? $clog2(MaxWrTxns) : 1;

  typedef logic [HtIdxWidth-1:0] ht_idx_t;
  typedef logic [LdIdxWidth-1:0] ld_idx_t;

  typedef struct packed {
    id_t        id;
    ld_idx_t    head, tail;
    logic       free;
    logic       expecting_b;
    hs_cnt_t    b_timeout_counter;
  } head_tail_t;

  typedef struct packed {
    logic [8:0]    expected_beats;
    write_state_t  write_state;
    ht_idx_t       ht_idx;
    ld_idx_t       next;
    logic          free;
  } linked_wr_data_t;

  head_tail_t      [HtCapacity-1:0] head_tail_n, head_tail_q;
  linked_wr_data_t [MaxWrTxns-1:0]  linked_data_n, linked_data_q;

  ld_idx_t         [MaxWrTxns-1:0]  w_fifo_q, w_fifo_n;
  logic            [PtrWidth-1:0]   wr_ptr_q, wr_ptr_n;
  logic            [PtrWidth-1:0]   rd_ptr_q, rd_ptr_n;
  logic                             fifo_full_q, fifo_full_n;
  logic                             fifo_empty_q, fifo_empty_n;

  ld_idx_t active_idx;
  assign active_idx = fifo_empty_q ? '0 : w_fifo_q[rd_ptr_q];

  // Counter 1: AW Pre-Handshake
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
    .budget_i   ( budget_avld_ardy_i                ),
    .timeout_o  ( timeout_aw                        ),
    .reset_o    ( reset_aw                          ),
    .abort_id_o ( abort_id_aw                       )
  );

  // Counter 2 (Shared W Liveness) + Shared W Beat Counter + Counter 3 (Per-ID B Timeout)
  hs_cnt_t    w_liveness_q, w_liveness_n;
  logic [8:0] w_beat_cnt_q, w_beat_cnt_n;
  logic       timeout_w, reset_w, timeout_b, reset_b;
  id_t        id_w, id_b;
  logic       proto_err, reset_proto;
  id_t        abort_id_proto;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      w_liveness_q <= '0;
      w_beat_cnt_q <= '0;
    end else if (reset_clear_i) begin
      w_liveness_q <= '0;
      w_beat_cnt_q <= '0;
    end else begin
      w_liveness_q <= w_liveness_n;
      w_beat_cnt_q <= w_beat_cnt_n;
    end
  end

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
    .aw_hs_i              ( aw_hs_i              ),
    .awid_q_i             ( awid_i               ),
    .awlen_q_i            ( awlen_i              ),
    .w_hs_i               ( w_hs_i               ),
    .w_valid_i            ( w_valid_i            ),
    .w_ready_i            ( w_ready_i            ),
    .wlast_q_i            ( wlast_i              ),
    .b_hs_i               ( b_hs_i               ),
    .b_valid_i            ( b_valid_i            ),
    .b_ready_i            ( b_ready_i            ),
    .bid_i                ( bid_i                ),
    .reset_req_o          ( reset_proto          ),
    .proto_err_o          ( proto_err            ),
    .abort_id_o           ( abort_id_proto       ),
    .head_tail_q_i        ( head_tail_q          ),
    .head_tail_n_o        ( head_tail_n          ),
    .linked_data_q_i      ( linked_data_q        ),
    .linked_data_n_o      ( linked_data_n        ),
    .evt_ovf_o            ( evt_ovf_o            ),
    .evt_ovf_id_o         ( evt_ovf_id_o         ),
    .fab_all_req_i        ( fab_all_req_i        ),
    .fab_b_valid_o        ( fab_b_valid_o        ),
    .fab_b_id_o           ( fab_b_id_o           ),
    .budget_w_liveness_i  ( budget_w_liveness_i  ),
    .budget_b_timeout_i   ( budget_b_timeout_i   ),
    .w_liveness_q_i       ( w_liveness_q         ),
    .w_liveness_n_o       ( w_liveness_n         ),
    .w_beat_cnt_q_i       ( w_beat_cnt_q         ),
    .w_beat_cnt_n_o       ( w_beat_cnt_n         ),
    .timeout_w_o          ( timeout_w            ),
    .reset_w_o            ( reset_w              ),
    .timeout_b_o          ( timeout_b            ),
    .reset_b_o            ( reset_b              ),
    .id_w_o               ( id_w                 ),
    .id_b_o               ( id_b                 )
  );

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

  logic slverr_b;
  assign slverr_b = !fab_all_req_i && b_hs_i && (bresp_i != axi_pkg::RESP_OKAY) &&
                    (bresp_i != axi_pkg::RESP_EXOKAY);

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
    end else if (timeout_w) begin
      abort_id_o    = id_w;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_WDATA;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_TIMEOUT;
    end else if (timeout_b) begin
      abort_id_o    = id_b;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_BRSP;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_TIMEOUT;
    end else if (proto_err) begin
      abort_id_o    = abort_id_proto;
      fault_pulse_o = 1'b1;
      fault_phase_o = (w_hs_i && !b_hs_i) ? axi_tmu_pkg::PH_WDATA : axi_tmu_pkg::PH_BRSP;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_PROTO;
    end else if (slverr_b) begin
      abort_id_o    = bid_i;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_BRSP;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_SLVERR;
    end else if (evt_ovf_o) begin
      abort_id_o    = evt_ovf_id_o;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_AW;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_OVERFLOW;
    end
  end

  assign timeout_o   = timeout_aw | timeout_w | timeout_b;
  assign reset_req_o = reset_aw | reset_w | reset_b | reset_proto | slverr_b;

endmodule