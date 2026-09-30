// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Chaoqun Liang <chaoqun.liang@unibo.it>

module read_guard
  import axi_tmu_pkg::*;
#(
  parameter int unsigned MaxUniqIds    = 32,
  parameter int unsigned MaxRdTxns     = 32,
  parameter type hs_cnt_t              = logic,
  parameter type id_t                  = logic
)(
  input  logic           clk_i,
  input  logic           rst_ni,
  // Registered bus views
  input  logic           ar_hs_i,
  input  logic           ar_ready_i,
  input  logic           ar_valid_i,
  input  id_t            arid_i,
  input  axi_pkg::len_t  arlen_i,

  input  logic           r_hs_i,
  input  logic           r_valid_i,
  input  logic           r_ready_i,
  input  id_t            r_id_i,
  input  logic           rlast_i,
  input  axi_pkg::resp_t rresp_i,

  // Prescaled tick for counters
  input  logic           prescaled_en_i,
  // CSR budgets
  input  hs_cnt_t        budget_arhs_rfirst_i,
  input  hs_cnt_t        budget_arvld_arrdy_i,
  input  hs_cnt_t        budget_rvld_rrdy_i,
  input  hs_cnt_t        budget_r_liveness_i,

  input  logic           reset_clear_i,
  output logic           reset_req_o,
  output logic           timeout_o,

  output logic           evt_ovf_o,
  output id_t            evt_ovf_id_o,

  output id_t            abort_id_o,

  input  logic           fab_all_req_i,
  output logic           fab_r_valid_o,
  output id_t            fab_r_id_o,
  output logic           fab_r_last_o,

  // Latency profiling outputs (10-bit CSRs)
  output logic [9:0]     lat_arvld_arrdy_o,
  output logic [9:0]     lat_arvld_rvld_o,
  output logic [9:0]     lat_rvld_rrdy_o,
  output logic [9:0]     lat_rvld_rlast_o,

  // Fault reporting
  output logic                        fault_pulse_o,
  output axi_tmu_pkg::tmu_phase_t     fault_phase_o,
  output axi_tmu_pkg::tmu_fault_type_t fault_type_o
);

  localparam int HtCapacity            = (MaxUniqIds <= MaxRdTxns) ? MaxUniqIds : MaxRdTxns;
  localparam int unsigned HtIdxWidth   = cf_math_pkg::idx_width(HtCapacity);
  localparam int unsigned LdIdxWidth   = cf_math_pkg::idx_width(MaxRdTxns);

  typedef logic [HtIdxWidth-1:0] ht_idx_t;
  typedef logic [LdIdxWidth-1:0] ld_idx_t;

  typedef struct packed {
    id_t        id;
    ld_idx_t    head, tail;
    logic       free;
    logic       rfirst_arm;       // Armed until first R handshake completes
    hs_cnt_t    arhs_rfirst_cnt;  // Stage 2: ARHS->First RVALID
    hs_cnt_t    rvld_rrdy_cnt;    // Stage 3: RVALID->RREADY (first beat only)
    hs_cnt_t    r_liveness_cnt;   // Stage 4: First R beat->RLAST inter-beat liveness
    logic [8:0] r_beat_cnt;
  } head_tail_t;

  typedef struct packed {
    logic [8:0]  expected_beats;
    read_state_t read_state;
    ld_idx_t     next;
    logic        free;
  } linked_rd_data_t;

  // Storage
  head_tail_t      [HtCapacity-1:0] head_tail_n, head_tail_q;
  linked_rd_data_t [MaxRdTxns-1:0]  linked_data_n, linked_data_q;

  // ==========================================================================
  // STAGE 1: AR Pre-Handshake (Channel-level)
  // ==========================================================================
  logic ar_valid_sticky, ar_ready_sticky;
  logic timeout_ar, reset_ar;
  id_t  abort_id_ar;

  sticky i_arvalid_sticky (
    .clk_i,
    .rst_ni,
    .release_i ( prescaled_en_i  ),
    .sticky_i  ( ar_valid_i      ),
    .sticky_o  ( ar_valid_sticky )
  );

  sticky i_arready_sticky (
    .clk_i,
    .rst_ni,
    .release_i ( prescaled_en_i  ),
    .sticky_i  ( ar_ready_i      ),
    .sticky_o  ( ar_ready_sticky )
  );

  tmu_hs_counter #(
    .hs_cnt_t ( hs_cnt_t ),
    .id_t     ( id_t     )
  ) i_ar_prehs (
    .clk_i,
    .rst_ni,
    .prescaled_en_i,
    .valid_i    ( ar_valid_sticky && !fab_all_req_i ),
    .ready_i    ( ar_ready_sticky                   ),
    .id_i       ( arid_i                            ),
    .budget_i   ( budget_arvld_arrdy_i              ),
    .timeout_o  ( timeout_ar                        ),
    .reset_o    ( reset_ar                          ),
    .abort_id_o ( abort_id_ar                       )
  );

  // ==========================================================================
  // STAGE 2-4: Post-ARHS Inflight Tracking
  // ==========================================================================
  logic proto_err, timeout_stage2, timeout_stage3, timeout_stage4;
  logic reset_stage2, reset_stage4, reset_proto;
  id_t  abort_id_proto, timeout_id_stage2, timeout_id_stage3, timeout_id_stage4;

  tmu_rd_inflight #(
    .MaxRdTxns     ( MaxRdTxns        ),
    .HtCapacity    ( HtCapacity       ),
    .linked_data_t ( linked_rd_data_t ),
    .head_tail_t   ( head_tail_t      ),
    .ht_idx_t      ( ht_idx_t         ),
    .ld_idx_t      ( ld_idx_t         ),
    .id_t          ( id_t             ),
    .hs_cnt_t      ( hs_cnt_t         )
  ) i_rd_inflight (
    .prescaled_en_i       ( prescaled_en_i       ),
    .reset_clear_i        ( reset_clear_i        ),
    .budget_arhs_rfirst_i ( budget_arhs_rfirst_i ),
    .budget_rvld_rrdy_i   ( budget_rvld_rrdy_i   ),
    .budget_r_liveness_i  ( budget_r_liveness_i  ),
    // Cycle-accurate AXI signals (no sticky stretching on handshakes/RLAST)
    .ar_hs_i              ( ar_hs_i              ),
    .arid_i               ( arid_i               ),
    .arlen_i              ( arlen_i              ),
    .r_hs_i               ( r_hs_i               ),
    .r_valid_i            ( r_valid_i            ),
    .r_ready_i            ( r_ready_i            ),
    .rlast_i              ( rlast_i              ),
    .rid_i                ( r_id_i               ),
    // Status outputs
    .reset_req_o          ( reset_proto          ),
    .proto_err_o          ( proto_err            ),
    .abort_id_o           ( abort_id_proto       ),

    .timeout_stage2_o     ( timeout_stage2       ),
    .timeout_stage3_o     ( timeout_stage3       ),
    .timeout_stage4_o     ( timeout_stage4       ),
    .reset_stage2_o       ( reset_stage2         ),
    .reset_stage4_o       ( reset_stage4         ),
    .timeout_id_stage2_o  ( timeout_id_stage2    ),
    .timeout_id_stage3_o  ( timeout_id_stage3    ),
    .timeout_id_stage4_o  ( timeout_id_stage4    ),

    .evt_ovf_o            ( evt_ovf_o            ),
    .evt_ovf_id_o         ( evt_ovf_id_o         ),
    // Table interfaces
    .head_tail_q_i        ( head_tail_q          ),
    .head_tail_n_o        ( head_tail_n          ),
    .linked_data_q_i      ( linked_data_q        ),
    .linked_data_n_o      ( linked_data_n        ),
    // Fabrication
    .fab_all_req_i        ( fab_all_req_i        ),
    .fab_r_valid_o        ( fab_r_valid_o        ),
    .fab_r_id_o           ( fab_r_id_o           ),
    .fab_r_last_o         ( fab_r_last_o         )
  );

  // Storage Flops
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int i = 0; i < HtCapacity; i++) begin
        head_tail_q[i] <= '{free: 1'b1, default: '0};
      end
      for (int i = 0; i < MaxRdTxns; i++) begin
        linked_data_q[i] <= '{free: 1'b1, default: '0};
      end
    end else begin
      head_tail_q   <= head_tail_n;
      linked_data_q <= linked_data_n;
    end
  end

  // ==========================================================================
  // Self-Reported Subordinate Error Detection (TMU_FLT_SLVERR)
  // ==========================================================================
  logic slverr_r;
  assign slverr_r = !fab_all_req_i && r_hs_i && (rresp_i != axi_pkg::RESP_OKAY) &&
                    (rresp_i != axi_pkg::RESP_EXOKAY);

  // ==========================================================================
  // Phase Latency Profiling Counters (10-bit High-Watermark CSRs)
  // ==========================================================================
  logic [9:0] cur_arvld_arrdy_q, max_arvld_arrdy_q;
  logic [9:0] max_arvld_rvld_q,  max_rvld_rrdy_q, max_rvld_rlast_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cur_arvld_arrdy_q <= '0;
      max_arvld_arrdy_q <= '0;
      max_arvld_rvld_q  <= '0;
      max_rvld_rrdy_q   <= '0;
      max_rvld_rlast_q  <= '0;
    end else if (reset_clear_i) begin
      cur_arvld_arrdy_q <= '0;
      max_arvld_arrdy_q <= '0;
      max_arvld_rvld_q  <= '0;
      max_rvld_rrdy_q   <= '0;
      max_rvld_rlast_q  <= '0;
    end else begin
      // 1. latency_arvld_arrdy
      if (ar_hs_i) begin
        if (cur_arvld_arrdy_q > max_arvld_arrdy_q)
          max_arvld_arrdy_q <= cur_arvld_arrdy_q;
        cur_arvld_arrdy_q <= '0;
      end else if (ar_valid_i && !ar_ready_i) begin
        if (cur_arvld_arrdy_q != 10'h3ff)
          cur_arvld_arrdy_q <= cur_arvld_arrdy_q + 10'd1;
      end

      // 2, 3, 4. Per-ID head counters mapped to high-watermark CSRs
      for (int k = 0; k < HtCapacity; k++) begin
        if (!head_tail_q[k].free) begin
          if (10'(head_tail_q[k].arhs_rfirst_cnt) > max_arvld_rvld_q)
            max_arvld_rvld_q <= 10'(head_tail_q[k].arhs_rfirst_cnt);
          if (10'(head_tail_q[k].rvld_rrdy_cnt) > max_rvld_rrdy_q)
            max_rvld_rrdy_q <= 10'(head_tail_q[k].rvld_rrdy_cnt);
          if (10'(head_tail_q[k].r_liveness_cnt) > max_rvld_rlast_q)
            max_rvld_rlast_q <= 10'(head_tail_q[k].r_liveness_cnt);
        end
      end
    end
  end

  assign lat_arvld_arrdy_o = max_arvld_arrdy_q;
  assign lat_arvld_rvld_o  = max_arvld_rvld_q;
  assign lat_rvld_rrdy_o   = max_rvld_rrdy_q;
  assign lat_rvld_rlast_o  = max_rvld_rlast_q;

  // ==========================================================================
  // Fault Priority and Output Assignment
  // ==========================================================================
  always_comb begin
    abort_id_o    = '0;
    fault_pulse_o = 1'b0;
    fault_phase_o = axi_tmu_pkg::PH_NONE;
    fault_type_o  = axi_tmu_pkg::TMU_FLT_NONE;

    if (timeout_ar) begin
      abort_id_o    = abort_id_ar;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_AR;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_TIMEOUT;
    end else if (timeout_stage2) begin
      abort_id_o    = timeout_id_stage2;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_RHEAD;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_TIMEOUT;
    end else if (timeout_stage3) begin
      abort_id_o    = timeout_id_stage3;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_RV2RR;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_TIMEOUT;
    end else if (timeout_stage4) begin
      abort_id_o    = timeout_id_stage4;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_RDATA;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_TIMEOUT;
    end else if (proto_err) begin
      abort_id_o    = abort_id_proto;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_RDATA;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_PROTO;
    end else if (slverr_r) begin
      abort_id_o    = r_id_i;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_RDATA;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_SLVERR;
    end else if (evt_ovf_o) begin
      abort_id_o    = evt_ovf_id_o;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_AR;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_OVERFLOW;
    end
  end

  assign timeout_o   = timeout_ar | timeout_stage2 | timeout_stage3 | timeout_stage4;
  assign reset_req_o = reset_ar | reset_proto | reset_stage2 | reset_stage4 | slverr_r;

endmodule