// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Chaoqun Liang <chaoqun.liang@unibo.it>

module read_guard #(
  parameter int unsigned MaxUniqIds   = 32,
  parameter int unsigned MaxTxnsPerId = 32,
  parameter type id_t                 = logic,
  parameter type hs_cnt_t             = logic,
  parameter type num_cnt_t            = logic,
  parameter type track_cnt_t          = logic
)(
  input  logic           clk_i,
  input  logic           rst_ni,
  input  logic           reset_clear_i,

  input  logic           prescaled_en_i,
  input  hs_cnt_t        budget_avld_ardy_i,
  input  logic [11:0]    budget_r2r_i,

  input  logic           ar_valid_i,
  input  logic           ar_ready_i,
  input  logic           ar_hs_i,
  input  id_t            arid_i,

  input  logic           r_last_i,
  input  logic           r_hs_i,
  input  id_t            rid_i,
  input  logic           r_ready_i,
  input  axi_pkg::resp_t rresp_i,

  output logic           reset_req_o,
  output logic           timeout_o,
  output id_t            abort_id_o,

  output logic           evt_ovf_o,
  output id_t            evt_ovf_id_o,

  input  logic           fab_all_req_i,
  output logic           fab_r_valid_o,
  output id_t            fab_r_id_o,

  output logic                         fault_pulse_o,
  output axi_tmu_pkg::tmu_phase_t      fault_phase_o,
  output axi_tmu_pkg::tmu_fault_type_t fault_type_o
);

  localparam int IdCapacity          = MaxUniqIds;
  localparam int unsigned HtIdxWidth = cf_math_pkg::idx_width(IdCapacity);

  typedef logic [HtIdxWidth-1:0] id_idx_t;

  typedef struct packed {
    id_t         id;
    num_cnt_t    num_txn;
    logic [11:0] r_timeout_cnt;
    logic        free;
  } id_queue_t;

  id_queue_t [IdCapacity-1:0] id_queue_n, id_queue_q;

  // STAGE 1: AR Pre-Handshake (Channel-level)
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
    .budget_i   ( budget_avld_ardy_i                ),
    .timeout_o  ( timeout_ar                        ),
    .reset_o    ( reset_ar                          ),
    .abort_id_o ( abort_id_ar                       )
  );

  logic proto_err, timeout_r;
  logic reset_proto;
  id_t  abort_id_proto, timeout_id_r;

  tmu_rd_inflight #(
    .MaxTxnsPerId  ( MaxTxnsPerId ),
    .HtCapacity    ( IdCapacity   ),
    .id_queue_t    ( id_queue_t   ),
    .ht_idx_t      ( id_idx_t     ),
    .id_t          ( id_t         ),
    .track_cnt_t   ( track_cnt_t  )
  ) i_rd_inflight (
    .prescaled_en_i ( prescaled_en_i ),
    .reset_clear_i  ( reset_clear_i  ),
    .ar_hs_i        ( ar_hs_i        ),
    .arid_i         ( arid_i         ),
    .r_hs_i         ( r_hs_i         ),
    .rid_i          ( rid_i          ),
    .r_last_i       ( r_last_i       ),
    .r_ready_i      ( r_ready_i      ),
    .head_tail_q_i  ( id_queue_q     ),
    .head_tail_n_o  ( id_queue_n     ),
    .reset_req_o    ( reset_proto    ),
    .evt_ovf_o      ( evt_ovf_o      ),
    .evt_ovf_id_o   ( evt_ovf_id_o   ),
    .abort_id_o     ( abort_id_proto ),
    .proto_err_o    ( proto_err      ),
    .fab_all_req_i  ( fab_all_req_i  ),
    .fab_r_valid_o  ( fab_r_valid_o  ),
    .fab_r_id_o     ( fab_r_id_o     ),
    .budget_r2r_i   ( budget_r2r_i   ),
    .timeout_r_o    ( timeout_r      ),
    .timeout_id_r_o ( timeout_id_r   )
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int i = 0; i < IdCapacity; i++) begin
        id_queue_q[i] <= '{free: 1'b1, default: '0};
      end
    end else begin
      id_queue_q <= id_queue_n;
    end
  end

  logic slverr_r;
  assign slverr_r = !fab_all_req_i && r_hs_i && (rresp_i != axi_pkg::RESP_OKAY) &&
                    (rresp_i != axi_pkg::RESP_EXOKAY);

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
    end else if (timeout_r) begin
      abort_id_o    = timeout_id_r;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_R;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_TIMEOUT;
    end else if (proto_err) begin
      abort_id_o    = abort_id_proto;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_R;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_PROTO;
    end else if (slverr_r) begin
      abort_id_o    = rid_i;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_R;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_SLVERR;
    end else if (evt_ovf_o) begin
      abort_id_o    = evt_ovf_id_o;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_AR;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_OVERFLOW;
    end
  end

  assign timeout_o   = timeout_ar | timeout_r;
  assign reset_req_o = reset_ar | reset_proto | slverr_r;

endmodule