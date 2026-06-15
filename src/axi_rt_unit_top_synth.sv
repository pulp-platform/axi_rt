// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Thomas Benz <enz@ethz.ch>

`include "axi/typedef.svh"
`include "axi/assign.svh"
`include "axi-rt/assign.svh"
`include "axi-rt/port.svh"
`include "apb/typedef.svh"

/// Synth Wrapper for the AXI RT unit
/// Codename `Mr Poopybutthole`
module axi_rt_unit_top_synth #(
  parameter int unsigned NumManagers      = 32'd8,
  parameter int unsigned PeriodWidth      = 32'd32,
  parameter int unsigned BudgetWidth      = 32'd32,
  parameter int unsigned WBufferDepth     = 32'd8,
  parameter int unsigned NumPending       = 32'd8,
  parameter int unsigned AxiIdWidth       = 32'd2,
  parameter int unsigned AxiAddrWidth     = 32'd32,
  parameter int unsigned AxiDataWidth     = 32'd64,
  parameter int unsigned AxiUserWidth     = 32'd1,
  parameter int unsigned NumAddrRegions   = 32'd2,
  parameter int unsigned RegIdWidth       = 32'd2,
  parameter bit          CutDecErrors     =  1'b0,
  parameter bit          CutSplitterPaths =  1'b0,
  // derived
  parameter int unsigned IdxWWidth      = cf_math_pkg::idx_width(WBufferDepth),
  parameter int unsigned IdxAwWidth     = cf_math_pkg::idx_width(NumPending),
  // derived types
  parameter type idx_w_t                = logic    [IdxWWidth-1     :0],
  parameter type idx_aw_t               = logic    [IdxAwWidth-1    :0],
  parameter type period_t               = logic    [PeriodWidth-1   :0],
  parameter type budget_t               = logic    [BudgetWidth-1   :0],
  parameter type period_array_t         = period_t [NumAddrRegions-1:0],
  parameter type budget_array_t         = budget_t [NumAddrRegions-1:0],
  parameter type id_t                   = logic    [AxiIdWidth-1    :0],
  parameter type reg_id_t               = logic    [RegIdWidth-1    :0],
  parameter type addr_t                 = logic    [AxiAddrWidth-1  :0],
  parameter type data_t                 = logic    [AxiDataWidth-1  :0],
  parameter type strb_t                 = logic    [AxiDataWidth/8-1:0],
  parameter type user_t                 = logic    [AxiUserWidth-1  :0],
  parameter type reg_data_t             = logic    [31              :0],
  parameter type reg_strb_t             = logic    [3               :0]
) (

  input  logic      clk_i,
  input  logic      rst_ni,

  `AXI_M_PORT_ARRAY(rt, NumManagers, addr_t, data_t, strb_t, id_t, user_t, user_t, user_t, user_t, user_t)
  `AXI_S_PORT_ARRAY(rt, NumManagers, addr_t, data_t, strb_t, id_t, user_t, user_t, user_t, user_t, user_t)

  input  addr_t     cfg_paddr_i,
  input  reg_data_t cfg_pwdata_i,
  input  reg_strb_t cfg_pstrb_i,
  input  logic      cfg_pwrite_i,
  input  logic      cfg_psel_i,
  input  logic      cfg_penable_i,
  output reg_data_t cfg_prdata_o,
  output logic      cfg_pready_o,
  output logic      cfg_pslverr_o,
  input  reg_id_t   reg_id_i
);

  `AXI_TYPEDEF_ALL(axi, addr_t, id_t, data_t, strb_t, user_t)

  axi_req_t  [NumManagers-1:0] m_req, s_req;
  axi_resp_t [NumManagers-1:0] m_rsp, s_rsp;

  `AXI_ASSIGN_MASTER_TO_FLAT_ARRAY(rt, NumManagers, m_req, m_rsp)
  `AXI_ASSIGN_SLAVE_TO_FLAT_ARRAY (rt, NumManagers, s_req, s_rsp)


  `APB_TYPEDEF_ALL(cfg, addr_t, reg_data_t, reg_strb_t)

  cfg_req_t  cfg_req;
  cfg_resp_t cfg_rsp;

  assign cfg_req.paddr   = cfg_paddr_i;
  assign cfg_req.pprot   = '0;
  assign cfg_req.psel    = cfg_psel_i;
  assign cfg_req.penable = cfg_penable_i;
  assign cfg_req.pwrite  = cfg_pwrite_i;
  assign cfg_req.pwdata  = cfg_pwdata_i;
  assign cfg_req.pstrb   = cfg_pstrb_i;
  assign cfg_prdata_o    = cfg_rsp.prdata;
  assign cfg_pready_o    = cfg_rsp.pready;
  assign cfg_pslverr_o   = cfg_rsp.pslverr;


  //-----------------------------------
  // DUT
  //-----------------------------------
  axi_rt_unit_top #(
    .NumManagers    ( NumManagers      ),
    .AddrWidth      ( AxiAddrWidth     ),
    .DataWidth      ( AxiDataWidth     ),
    .IdWidth        ( AxiIdWidth       ),
    .UserWidth      ( AxiUserWidth     ),
    .NumPending     ( NumPending       ),
    .WBufferDepth   ( WBufferDepth     ),
    .NumAddrRegions ( NumAddrRegions   ),
    .BudgetWidth    ( BudgetWidth      ),
    .PeriodWidth    ( PeriodWidth      ),
    .CutDecErrors   ( CutDecErrors     ),
    .RegIdWidth     ( RegIdWidth       ),
    .aw_chan_t      ( axi_aw_chan_t    ),
    .ar_chan_t      ( axi_ar_chan_t    ),
    .w_chan_t       ( axi_w_chan_t     ),
    .b_chan_t       ( axi_b_chan_t     ),
    .r_chan_t       ( axi_r_chan_t     ),
    .axi_req_t      ( axi_req_t        ),
    .axi_resp_t     ( axi_resp_t       ),
    .apb_req_t      ( cfg_req_t        ),
    .apb_resp_t     ( cfg_resp_t       )
  ) i_axi_rt_unit_top (
    .clk_i,
    .rst_ni,
    .slv_req_i        ( s_req         ),
    .slv_resp_o       ( s_rsp         ),
    .mst_req_o        ( m_req         ),
    .mst_resp_i       ( m_rsp         ),
    .apb_req_i        ( cfg_req       ),
    .apb_rsp_o        ( cfg_rsp       ),
    .reg_id_i         ( reg_id_i      )
  );

endmodule
