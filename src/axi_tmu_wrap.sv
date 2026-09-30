// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Chaoqun Liang <chaoqun.liang@unibo.it>

import axi_tmu_pkg::*;

module tmu_wrap (
  input  logic               clk_i,
  input  logic               rst_ni,
  input  mgr_req_t           mgr_req,
  output mgr_rsp_t           mgr_rsp,
  output sbr_req_t           sbr_req,
  input  sbr_rsp_t           sbr_rsp,
  input  cfg_req_t           cfg_req,
  /// Register bus response
  output cfg_rsp_t           cfg_rsp,
  /// Interrupt line
  output logic               fault,
  /// Reset request
  output logic               rst_req,
  /// Reset status
  input  logic               rst_stat
);

axi_tmu_top #(
  .MaxUniqIds    (MaxUniqIds),
  .MaxTxnsPerId  (MaxTxnsPerId),
  .MaxWrTxns     (MaxWrTxns  ),
  .MaxRdTxns     (MaxRdTxns),
  .AxiIdWidth    (AxiIdWidth),
  .HsCntWidth    (HsCntWidth),
  .PrescalerDiv  (PrescalerDiv),
  .mgr_req_t    ( mgr_req_t       ),
  .mgr_rsp_t    ( mgr_rsp_t      ),
  .sbr_req_t    ( sbr_req_t       ),
  .sbr_rsp_t    ( sbr_rsp_t      ),
  .cfg_req_t    ( cfg_req_t       ),
  .cfg_rsp_t    ( cfg_rsp_t       )
) i_axi_tmu (
  .clk_i       (   clk_i        ),
  .rst_ni      (   rst_ni        ),
  .mgr_req_i   (   mgr_req      ),
  .mgr_rsp_o   (   mgr_rsp      ),
  .sbr_req_o   (   sbr_req      ),
  .sbr_rsp_i   (   sbr_rsp      ),
  .cfg_req_i   (   cfg_req    ),
  .cfg_rsp_o   (   cfg_rsp    ),
  .fault_o     (   fault      ),
  .rst_req_o   (   rst_req    ),
  .reset_clear_i ( rst_stat   )
);

 endmodule: tmu_wrap