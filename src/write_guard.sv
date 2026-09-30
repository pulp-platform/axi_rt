// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Chaoqun Liang <chaoqun.liang@unibo.it>

module write_guard #(
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
  input  track_cnt_t     budget_b2b_i,

  input  logic           aw_valid_i,
  input  logic           aw_ready_i,
  input  logic           aw_hs_i,
  input  id_t            aw_id_i,

  input  logic           b_hs_i,
  input  id_t            bid_i,
  input  logic           b_ready_i,
  input  axi_pkg::resp_t bresp_i,

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

  localparam int IdCapacity          = MaxUniqIds;
  localparam int unsigned HtIdxWidth = cf_math_pkg::idx_width(IdCapacity);

  typedef logic [HtIdxWidth-1:0] id_idx_t;

  typedef struct packed {
    id_t        id;
    num_cnt_t   num_txn;
    track_cnt_t b_timeout_cnt;
    logic       free;
  } id_queue_t;

  id_queue_t [IdCapacity-1:0] id_queue_n, id_queue_q;

  // STAGE 1: AW Pre-Handshake (AWVALID -> AWREADY)
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
    .id_i       ( aw_id_i                           ),
    .budget_i   ( budget_avld_ardy_i                ),
    .timeout_o  ( timeout_aw                        ),
    .reset_o    ( reset_aw                          ),
    .abort_id_o ( abort_id_aw                       )
  );

  logic timeout_b;
  id_t  timeout_id_b;
  logic proto_err, reset_proto;
  id_t  abort_id_proto;

  tmu_wr_inflight #(
    .HtCapacity    ( IdCapacity   ),
    .MaxTxnsPerId  ( MaxTxnsPerId ),
    .id_queue_t    ( id_queue_t   ),
    .ht_idx_t      ( id_idx_t     ),
    .id_t          ( id_t         ),
    .track_cnt_t   ( track_cnt_t  )
  ) i_wr_inflight (
    .prescaled_en_i ( prescaled_en_i ),
    .reset_clear_i  ( reset_clear_i  ),
    .aw_hs_i        ( aw_hs_i        ),
    .awid_q_i       ( aw_id_i        ),
    .b_hs_i         ( b_hs_i         ),
    .bid_i          ( bid_i          ),
    .b_ready_i      ( b_ready_i      ),
    .head_tail_q_i  ( id_queue_q     ),
    .head_tail_n_o  ( id_queue_n     ),
    .reset_req_o    ( reset_proto    ),
    .evt_ovf_o      ( evt_ovf_o      ),
    .evt_ovf_id_o   ( evt_ovf_id_o   ),
    .abort_id_o     ( abort_id_proto ),
    .proto_err_o    ( proto_err      ),
    .fab_all_req_i  ( fab_all_req_i  ),
    .fab_b_valid_o  ( fab_b_valid_o  ),
    .fab_b_id_o     ( fab_b_id_o     ),
    .budget_b2b_i   ( budget_b2b_i   ),
    .timeout_b_o    ( timeout_b      ),
    .timeout_id_b_o ( timeout_id_b   )
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
    end else if (timeout_b) begin
      abort_id_o    = timeout_id_b;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_B;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_TIMEOUT;
    end else if (proto_err) begin
      abort_id_o    = abort_id_proto;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_B;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_PROTO;
    end else if (slverr_b) begin
      abort_id_o    = bid_i;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_B;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_SLVERR;
    end else if (evt_ovf_o) begin
      abort_id_o    = evt_ovf_id_o;
      fault_pulse_o = 1'b1;
      fault_phase_o = axi_tmu_pkg::PH_AW;
      fault_type_o  = axi_tmu_pkg::TMU_FLT_OVERFLOW;
    end
  end

  assign timeout_o   = timeout_aw | timeout_b;
  assign reset_req_o = reset_aw |  reset_proto | slverr_b;

endmodule