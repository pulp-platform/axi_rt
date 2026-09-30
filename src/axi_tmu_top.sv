// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Chaoqun Liang <chaoqun.liang@unibo.it>

module axi_tmu_top
  import axi_tmu_pkg::*;
#(
  parameter int unsigned MaxUniqIds    = 16,
  parameter int unsigned MaxTxnsPerId  = 2,
  parameter int unsigned MaxWrTxns     = 32,
  parameter int unsigned MaxRdTxns     = 32,
  parameter int unsigned AxiIdWidth    = 6,
  // Counter
  parameter int unsigned HsCntWidth    = 4,
  parameter int unsigned PrescalerDiv  = 8,
  // Bundles
  parameter type mgr_req_t             = logic,
  parameter type mgr_rsp_t             = logic,
  parameter type sbr_req_t             = logic,
  parameter type sbr_rsp_t             = logic,
  // Reg bus
  parameter type cfg_req_t             = logic,
  parameter type cfg_rsp_t             = logic
)(
  input  logic      clk_i,
  input  logic      rst_ni,

  input  mgr_req_t  mgr_req_i,
  output mgr_rsp_t  mgr_rsp_o,
  output sbr_req_t  sbr_req_o,
  input  sbr_rsp_t  sbr_rsp_i,

  input  cfg_req_t  cfg_req_i,
  output cfg_rsp_t  cfg_rsp_o,

  // Fault/reset orchestration
  output logic      fault_o,       // interrupt line
  output logic      rst_req_o,     // to external slave reset device
  input  logic      reset_clear_i  // from external reset device
);

  localparam int unsigned IntIdWidth = (MaxUniqIds > 1) ? $clog2(MaxUniqIds) : 1;
  typedef logic [HsCntWidth-1:0] hs_cnt_t;
  typedef logic [AxiIdWidth-1:0] id_t;
  typedef logic [IntIdWidth-1:0] int_id_t;

  initial begin
    if (MaxRdTxns > MaxUniqIds*MaxTxnsPerId) begin
      $error("MaxRdTxns=%0d exceeds MaxUniqIds*MaxTxnsPerId=%0d", MaxRdTxns, MaxUniqIds*MaxTxnsPerId);
    end
    if (MaxWrTxns > MaxUniqIds*MaxTxnsPerId) begin
      $error("MaxWrTxns=%0d exceeds MaxUniqIds*MaxTxnsPerId=%0d", MaxWrTxns, MaxUniqIds*MaxTxnsPerId);
    end
  end

  // ==========================================================================
  // Register Block
  // ==========================================================================
  axi_tmu_reg_pkg::axi_tmu_reg2hw_t reg2hw;
  axi_tmu_reg_pkg::axi_tmu_hw2reg_t hw2reg;

  axi_tmu_reg_top #(
    .reg_req_t(cfg_req_t),
    .reg_rsp_t(cfg_rsp_t)
  ) i_regs (
    .clk_i,
    .rst_ni,
    .reg_req_i ( cfg_req_i ),
    .reg_rsp_o ( cfg_rsp_o ),
    .reg2hw    ( reg2hw    ),
    .hw2reg    ( hw2reg    ),
    .devmode_i ( 1'b1      )
  );

  hs_cnt_t budget_awvld_awrdy, budget_wvld_wrdy, budget_wlast_bvld, budget_bvld_brdy;
  hs_cnt_t budget_arvld_arrdy, budget_rvld_rrdy, budget_awhs_wfirst, budget_arhs_rfirst;
  hs_cnt_t budget_r_liveness,  budget_w_liveness;

  // Fallback to max budget ('1) when CSR is at reset value 0
  assign budget_awvld_awrdy = (reg2hw.budget_awvld_awrdy.q == '0) ? '1 : hs_cnt_t'(reg2hw.budget_awvld_awrdy.q);
  assign budget_awhs_wfirst = (reg2hw.budget_awhs_wfirst.q == '0) ? '1 : hs_cnt_t'(reg2hw.budget_awhs_wfirst.q);
  assign budget_wvld_wrdy   = (reg2hw.budget_wvld_wrdy.q   == '0) ? '1 : hs_cnt_t'(reg2hw.budget_wvld_wrdy.q);
  assign budget_wlast_bvld  = (reg2hw.budget_wlast_bvld.q  == '0) ? '1 : hs_cnt_t'(reg2hw.budget_wlast_bvld.q);
  assign budget_bvld_brdy   = (reg2hw.budget_bvld_brdy.q   == '0) ? '1 : hs_cnt_t'(reg2hw.budget_bvld_brdy.q);
  assign budget_arvld_arrdy = (reg2hw.budget_arvld_arrdy.q == '0) ? '1 : hs_cnt_t'(reg2hw.budget_arvld_arrdy.q);
  assign budget_rvld_rrdy   = (reg2hw.budget_rvld_rrdy.q   == '0) ? '1 : hs_cnt_t'(reg2hw.budget_rvld_rrdy.q);
  assign budget_arhs_rfirst = (reg2hw.budget_arhs_rfirst.q == '0) ? '1 : hs_cnt_t'(reg2hw.budget_arhs_rfirst.q);
  assign budget_r_liveness  = (reg2hw.budget_r_liveness.q  == '0) ? '1 : hs_cnt_t'(reg2hw.budget_r_liveness.q);
  assign budget_w_liveness  = (reg2hw.budget_w_liveness.q  == '0) ? '1 : hs_cnt_t'(reg2hw.budget_w_liveness.q);

  // ==========================================================================
  // Cut-and-Drain Datapath & ID Remapper
  // ==========================================================================
  sbr_req_t remap_req;
  sbr_rsp_t sbr_rsp_isolated;
  logic     cut;

  tmu_id_remap #(
    .AxiSlvPortIdWidth    ( AxiIdWidth   ),
    .AxiSlvPortMaxUniqIds ( MaxUniqIds   ),
    .AxiMaxTxnsPerId      ( MaxTxnsPerId ),
    .AxiMstPortIdWidth    ( IntIdWidth   ),
    .slv_req_t            ( mgr_req_t    ),
    .slv_resp_t           ( mgr_rsp_t    ),
    .mst_req_t            ( sbr_req_t    ),
    .mst_resp_t           ( sbr_rsp_t    )
  ) i_id_remap (
    .clk_i,
    .rst_ni,
    .slv_req_i  ( mgr_req_i        ),
    .slv_resp_o ( mgr_rsp_o        ),
    .mst_req_o  ( remap_req        ),
    .mst_resp_i ( sbr_rsp_isolated )
  );

  // Registered versions for normal monitoring; during cut, use direct signals
  // so fabrication handshakes step in exact lockstep with i_id_remap.
  sbr_req_t mgr_req_mon_q, mgr_req_mon;
  sbr_rsp_t sbr_rsp_mon_q, sbr_rsp_mon;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      mgr_req_mon_q <= '0;
      sbr_rsp_mon_q <= '0;
    end else begin
      mgr_req_mon_q <= remap_req;
      sbr_rsp_mon_q <= sbr_rsp_isolated;
    end
  end

  assign mgr_req_mon = cut ? remap_req        : mgr_req_mon_q;
  assign sbr_rsp_mon = cut ? sbr_rsp_isolated : sbr_rsp_mon_q;

  logic aw_hs, w_hs, b_hs, ar_hs, r_hs;
  assign aw_hs = mgr_req_mon.aw_valid && sbr_rsp_mon.aw_ready;
  assign w_hs  = mgr_req_mon.w_valid  && sbr_rsp_mon.w_ready;
  assign b_hs  = sbr_rsp_mon.b_valid  && mgr_req_mon.b_ready;
  assign ar_hs = mgr_req_mon.ar_valid && sbr_rsp_mon.ar_ready;
  assign r_hs  = sbr_rsp_mon.r_valid  && mgr_req_mon.r_ready;

  // Prescaler
  logic prescaled_en;

  timebase #(
    .DivFactor(PrescalerDiv)
  ) i_prescaler (
    .clk_i,
    .rst_ni,
    .tick_o(prescaled_en)
  );

  // Guard outputs
  logic          wr_timeout, wr_reset_req, rd_reset_req;
  int_id_t       wr_abort_id;
  logic          wr_evt_ovf;
  int_id_t       wr_evt_ovf_id;
  logic          wr_fab_b_valid;
  int_id_t       wr_fab_b_id;
  logic          wr_fault_pulse;
  tmu_phase_t    wr_fault_phase;
  axi_tmu_pkg::tmu_fault_type_t wr_fault_type;

  logic          rd_timeout;
  int_id_t       rd_abort_id;
  logic          rd_evt_ovf;
  int_id_t       rd_evt_ovf_id;
  logic          rd_fab_r_valid;
  int_id_t       rd_fab_r_id;
  logic          rd_fab_r_last;
  logic          rd_fault_pulse;
  tmu_phase_t    rd_fault_phase;
  axi_tmu_pkg::tmu_fault_type_t rd_fault_type;

  logic          wr_fab_all_req, rd_fab_all_req;

  // Latency profiling wires
  logic [9:0] lat_awvld_wfirst, lat_wvld_wrdy, lat_wvld_wlast, lat_wlast_bvld, lat_bvld_brdy;
  logic [9:0] lat_arvld_arrdy,  lat_arvld_rvld, lat_rvld_rrdy, lat_rvld_rlast;

  // Write Guard
  write_guard #(
    .MaxUniqIds   ( MaxUniqIds   ),
    .MaxWrTxns    ( MaxWrTxns    ),
    .hs_cnt_t     ( hs_cnt_t     ),
    .id_t         ( int_id_t     )
  ) i_write_guard (
    .clk_i,
    .rst_ni,
    .reset_clear_i        ( reset_clear_i          ),
    .prescaled_en_i       ( prescaled_en           ),
    .aw_hs_i              ( aw_hs                  ),
    .aw_valid_i           ( mgr_req_mon.aw_valid   ),
    .w_hs_i               ( w_hs                   ),
    .w_valid_i            ( mgr_req_mon.w_valid    ),
    .b_hs_i               ( b_hs                   ),
    .awid_i               ( mgr_req_mon.aw.id      ),
    .awlen_i              ( mgr_req_mon.aw.len     ),
    .wlast_i              ( mgr_req_mon.w.last     ),
    .bid_i                ( sbr_rsp_mon.b.id       ),
    .bresp_i              ( sbr_rsp_mon.b.resp     ),
    .aw_ready_i           ( sbr_rsp_mon.aw_ready   ),
    .w_ready_i            ( sbr_rsp_mon.w_ready    ),
    .b_valid_i            ( sbr_rsp_mon.b_valid    ),
    .b_ready_i            ( mgr_req_mon.b_ready    ),
    .budget_owner_wvld_i  ( budget_awhs_wfirst     ),
    .budget_awvld_awrdy_i ( budget_awvld_awrdy     ),
    .budget_wvld_wrdy_i   ( budget_wvld_wrdy       ),
    .budget_wlast_bvld_i  ( budget_wlast_bvld      ),
    .budget_bvld_brdy_i   ( budget_bvld_brdy       ),
    .budget_inter_beat_i  ( budget_w_liveness      ),

    .abort_id_o           ( wr_abort_id            ),
    .reset_req_o          ( wr_reset_req           ),
    .timeout_o            ( wr_timeout             ),
    .evt_ovf_o            ( wr_evt_ovf             ),
    .evt_ovf_id_o         ( wr_evt_ovf_id          ),
    .fab_all_req_i        ( wr_fab_all_req         ),
    .fab_b_valid_o        ( wr_fab_b_valid         ),
    .fab_b_id_o           ( wr_fab_b_id            ),
    .lat_awvld_wfirst_o   ( lat_awvld_wfirst       ),
    .lat_wvld_wrdy_o      ( lat_wvld_wrdy          ),
    .lat_wvld_wlast_o     ( lat_wvld_wlast         ),
    .lat_wlast_bvld_o     ( lat_wlast_bvld         ),
    .lat_bvld_brdy_o      ( lat_bvld_brdy          ),
    .fault_pulse_o        ( wr_fault_pulse         ),
    .fault_phase_o        ( wr_fault_phase         ),
    .fault_type_o         ( wr_fault_type          )
  );

  // Read Guard
  read_guard #(
    .MaxUniqIds   ( MaxUniqIds   ),
    .MaxRdTxns    ( MaxRdTxns    ),
    .hs_cnt_t     ( hs_cnt_t     ),
    .id_t         ( int_id_t     )
  ) i_read_guard (
    .clk_i,
    .rst_ni,
    .prescaled_en_i       ( prescaled_en           ),
    .ar_hs_i              ( ar_hs                  ),
    .ar_valid_i           ( mgr_req_mon.ar_valid   ),
    .ar_ready_i           ( sbr_rsp_mon.ar_ready   ),
    .arid_i               ( mgr_req_mon.ar.id      ),
    .arlen_i              ( mgr_req_mon.ar.len     ),
    .r_hs_i               ( r_hs                   ),
    .r_valid_i            ( sbr_rsp_mon.r_valid    ),
    .r_ready_i            ( mgr_req_mon.r_ready    ),
    .r_id_i               ( sbr_rsp_mon.r.id       ),
    .rlast_i              ( sbr_rsp_mon.r.last     ),
    .rresp_i              ( sbr_rsp_mon.r.resp     ),
    .budget_arvld_arrdy_i ( budget_arvld_arrdy     ),
    .budget_arhs_rfirst_i ( budget_arhs_rfirst     ),
    .budget_rvld_rrdy_i   ( budget_rvld_rrdy       ),
    .budget_r_liveness_i  ( budget_r_liveness      ),
    .reset_clear_i        ( reset_clear_i          ),
    .reset_req_o          ( rd_reset_req           ),
    .timeout_o            ( rd_timeout             ),
    .evt_ovf_o            ( rd_evt_ovf             ),
    .evt_ovf_id_o         ( rd_evt_ovf_id          ),
    .abort_id_o           ( rd_abort_id            ),
    .fab_all_req_i        ( rd_fab_all_req         ),
    .fab_r_valid_o        ( rd_fab_r_valid         ),
    .fab_r_id_o           ( rd_fab_r_id            ),
    .fab_r_last_o         ( rd_fab_r_last          ),
    .lat_arvld_arrdy_o    ( lat_arvld_arrdy        ),
    .lat_arvld_rvld_o     ( lat_arvld_rvld         ),
    .lat_rvld_rrdy_o      ( lat_rvld_rrdy          ),
    .lat_rvld_rlast_o     ( lat_rvld_rlast         ),
    .fault_pulse_o        ( rd_fault_pulse         ),
    .fault_phase_o        ( rd_fault_phase         ),
    .fault_type_o         ( rd_fault_type          )
  );

  // ==========================================================================
  // Fault Management with Cascading Prevention
  // ==========================================================================
  logic first_fault_occurred;
  logic wr_timeout_latched, rd_timeout_latched;
  logic wr_reset_req_latched, rd_reset_req_latched;
  logic fault_active;

  logic                         fault_logged;
  tmu_dir_t                     fault_dir_latched;
  axi_tmu_pkg::tmu_fault_type_t fault_type_latched;
  int_id_t                      fault_id_latched;
  tmu_phase_t                   fault_phase_latched;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      first_fault_occurred <= 1'b0;
      wr_timeout_latched   <= 1'b0;
      rd_timeout_latched   <= 1'b0;
      wr_reset_req_latched <= 1'b0;
      rd_reset_req_latched <= 1'b0;
      fault_active         <= 1'b0;
      fault_logged         <= 1'b0;
      fault_dir_latched    <= TMU_DIR_NONE;
      fault_type_latched   <= TMU_FLT_NONE;
      fault_id_latched     <= '0;
      fault_phase_latched  <= PH_NONE;
    end else if (reset_clear_i) begin
      first_fault_occurred <= 1'b0;
      wr_timeout_latched   <= 1'b0;
      rd_timeout_latched   <= 1'b0;
      wr_reset_req_latched <= 1'b0;
      rd_reset_req_latched <= 1'b0;
      fault_active         <= 1'b0;
      fault_logged         <= 1'b0;
      fault_dir_latched    <= TMU_DIR_NONE;
      fault_type_latched   <= TMU_FLT_NONE;
      fault_id_latched     <= '0;
      fault_phase_latched  <= PH_NONE;
    end else if (!first_fault_occurred) begin
      if (wr_timeout || wr_reset_req || wr_fault_pulse) begin
        wr_timeout_latched   <= wr_timeout;
        wr_reset_req_latched <= wr_reset_req;
        first_fault_occurred <= 1'b1;
        fault_active         <= 1'b1;

        if (!fault_logged) begin
          fault_logged        <= 1'b1;
          fault_dir_latched   <= TMU_DIR_WRITE;
          fault_type_latched  <= wr_fault_type;
          fault_id_latched    <= wr_abort_id;
          fault_phase_latched <= wr_fault_phase;
        end
      end else if (rd_timeout || rd_reset_req || rd_fault_pulse) begin
        rd_timeout_latched   <= rd_timeout;
        rd_reset_req_latched <= rd_reset_req;
        first_fault_occurred <= 1'b1;
        fault_active         <= 1'b1;

        if (!fault_logged) begin
          fault_logged        <= 1'b1;
          fault_dir_latched   <= TMU_DIR_READ;
          fault_type_latched  <= rd_fault_type;
          fault_id_latched    <= rd_abort_id;
          fault_phase_latched <= rd_fault_phase;
        end
      end
    end
  end

  // Cut-and-drain activation across both channels upon subordinate fault
  assign cut            = wr_timeout_latched | wr_reset_req_latched |
                          rd_timeout_latched | rd_reset_req_latched;
  assign wr_fab_all_req = cut;
  assign rd_fab_all_req = cut;

  // Datapath multiplexing with cut-and-drain isolation
  always_comb begin
    sbr_req_o        = remap_req;
    sbr_rsp_isolated = sbr_rsp_i;

    if (cut) begin
      // Fence downstream subordinate requests and response handshakes
      sbr_req_o.aw_valid        = 1'b0;
      sbr_req_o.w_valid         = 1'b0;
      sbr_req_o.ar_valid        = 1'b0;
      sbr_req_o.b_ready         = 1'b0;
      sbr_req_o.r_ready         = 1'b0;

      // Drain upstream AW/AR/W requests and mask late subordinate B/R
      sbr_rsp_isolated.aw_ready = 1'b1;
      sbr_rsp_isolated.ar_ready = 1'b1;
      sbr_rsp_isolated.w_ready  = 1'b1;
      sbr_rsp_isolated.b_valid  = 1'b0;
      sbr_rsp_isolated.r_valid  = 1'b0;
    end

    if (wr_fab_b_valid) begin
      sbr_rsp_isolated.b_valid = 1'b1;
      sbr_rsp_isolated.b.resp  = axi_pkg::RESP_SLVERR;
      sbr_rsp_isolated.b.id    = wr_fab_b_id;
      sbr_rsp_isolated.b.user  = '0;
    end

    if (rd_fab_r_valid) begin
      sbr_rsp_isolated.r_valid = 1'b1;
      sbr_rsp_isolated.r.resp  = axi_pkg::RESP_SLVERR;
      sbr_rsp_isolated.r.last  = rd_fab_r_last;
      sbr_rsp_isolated.r.id    = rd_fab_r_id;
      sbr_rsp_isolated.r.data  = '0;
      sbr_rsp_isolated.r.user  = '0;
    end
  end

  // ==========================================================================
  // Fault Logging & Latency Profiling to Registers
  // ==========================================================================
  logic faultlog_we;
  assign faultlog_we = (!fault_logged && (wr_fault_pulse || rd_fault_pulse)) ||
                       (wr_evt_ovf || rd_evt_ovf);

  axi_tmu_pkg::tmu_fault_log_t faultlog_d;

  always_comb begin
    faultlog_d = '0;
    if (!fault_logged) begin
      if (wr_fault_pulse) begin
        faultlog_d.fvalid = 1'b1;
        faultlog_d.fdir   = TMU_DIR_WRITE;
        faultlog_d.ftype  = wr_fault_type;
        faultlog_d.fid    = wr_abort_id;
        faultlog_d.fphase = wr_fault_phase;
      end else if (rd_fault_pulse) begin
        faultlog_d.fvalid = 1'b1;
        faultlog_d.fdir   = TMU_DIR_READ;
        faultlog_d.ftype  = rd_fault_type;
        faultlog_d.fid    = rd_abort_id;
        faultlog_d.fphase = rd_fault_phase;
      end
    end
  end

  assign hw2reg.fault_log.fault_valid.de = faultlog_we;
  assign hw2reg.fault_log.fault_type.de  = faultlog_we;
  assign hw2reg.fault_log.fault_dir.de   = faultlog_we;
  assign hw2reg.fault_log.fault_id.de    = faultlog_we;
  assign hw2reg.fault_log.fault_phase.de = faultlog_we;
  assign hw2reg.reset.de                 = faultlog_we;

  always_comb begin
    if (fault_logged) begin
      hw2reg.fault_log.fault_valid.d = 1'b1;
      hw2reg.fault_log.fault_type.d  = fault_type_latched;
      hw2reg.fault_log.fault_dir.d   = (fault_dir_latched == TMU_DIR_WRITE);
      hw2reg.fault_log.fault_id.d    = 16'(fault_id_latched);
      hw2reg.fault_log.fault_phase.d = fault_phase_latched;
    end else begin
      hw2reg.fault_log.fault_valid.d = faultlog_we ? faultlog_d.fvalid : 1'b0;
      hw2reg.fault_log.fault_type.d  = faultlog_we ? faultlog_d.ftype  : '0;
      hw2reg.fault_log.fault_dir.d   = faultlog_we ? (faultlog_d.fdir == TMU_DIR_WRITE) : 1'b0;
      hw2reg.fault_log.fault_id.d    = faultlog_we ? 16'(faultlog_d.fid) : '0;
      hw2reg.fault_log.fault_phase.d = faultlog_we ? faultlog_d.fphase : '0;
    end
    hw2reg.reset.d = rst_req_o ? 1'b1 : 1'b0;

    // Latency CSR connections
    hw2reg.latency_awvld_wfirst.de = 1'b1;
    hw2reg.latency_awvld_wfirst.d  = lat_awvld_wfirst;
    hw2reg.latency_wvld_wrdy.de    = 1'b1;
    hw2reg.latency_wvld_wrdy.d     = lat_wvld_wrdy;
    hw2reg.latency_wvld_wlast.de   = 1'b1;
    hw2reg.latency_wvld_wlast.d    = lat_wvld_wlast;
    hw2reg.latency_wlast_bvld.de   = 1'b1;
    hw2reg.latency_wlast_bvld.d    = lat_wlast_bvld;
    hw2reg.latency_bvld_brdy.de    = 1'b1;
    hw2reg.latency_bvld_brdy.d     = lat_bvld_brdy;
    hw2reg.latency_arvld_arrdy.de  = 1'b1;
    hw2reg.latency_arvld_arrdy.d   = lat_arvld_arrdy;
    hw2reg.latency_arvld_rvld.de   = 1'b1;
    hw2reg.latency_arvld_rvld.d    = lat_arvld_rvld;
    hw2reg.latency_rvld_rrdy.de    = 1'b1;
    hw2reg.latency_rvld_rrdy.d     = lat_rvld_rrdy;
    hw2reg.latency_rvld_rlast.de   = 1'b1;
    hw2reg.latency_rvld_rlast.d    = lat_rvld_rlast;
  end

  assign fault_o   = fault_active || wr_evt_ovf || rd_evt_ovf;
  assign rst_req_o = wr_reset_req_latched || rd_reset_req_latched;

endmodule