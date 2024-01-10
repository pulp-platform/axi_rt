// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Alessandro Ottaviano <aottaviano@iis.ee.ethz.ch>
// - Thomas Benz <tbenz@iis.ee.ethz.ch>

`include "axi/typedef.svh"
`include "axi/assign.svh"
`include "axi-rt/assign.svh"
`include "axi-rt/port.svh"
`include "register_interface/typedef.svh"

/// Xilinx Wrapper for the AXI RT unit
module axi_rt_unit_top_xilinx #(
  // Number of managers
  parameter int unsigned RtNumManagers = 0,
  // Number of regions per manager
  parameter int unsigned RtNumRegions = 0,
  // Number of outstanding transactions
  parameter int unsigned RtNumPending = 0,
  // Depth of the Buffer
  parameter int unsigned RtWBufferDepth = 0,
  // Period width
  parameter int unsigned RtPeriodWidth = 0,
  // Budget width
  parameter int unsigned RtBudgetWidth = 0,
  // Enable internal cuts in the RT units
  parameter int unsigned RtCutPaths = 0,
  // Enable transaction checks within the RT units
  parameter int unsigned RtEnableChecks = 0,
  // Enable internal cuts (a flop) for decode errors
  parameter int unsigned RtCutDecErrors = 0,
  // AXI configuration
  parameter int unsigned RtAxiIdWidth = 0,
  parameter int unsigned RtAxiAddrWidth = 0,
  parameter int unsigned RtAxiDataWidth = 0,
  parameter int unsigned RtAxiUserWidth = 0,
  // AXI Lite configuration
  parameter int unsigned RtAxiLiteAddrWidth = 0,
  parameter int unsigned RtAxiLiteDataWidth = 0,
  // Register configuration
  parameter int unsigned RtRegIdWidth = 0,
  // derived types for AXI interface
  parameter type axi_id_t   = logic [RtAxiIdWidth-1    :0],
  parameter type axi_addr_t = logic [RtAxiAddrWidth-1  :0],
  parameter type axi_data_t = logic [RtAxiDataWidth-1  :0],
  parameter type axi_strb_t = logic [RtAxiDataWidth/8-1:0],
  parameter type axi_user_t = logic [RtAxiUserWidth-1  :0],
  // derived types for AXI-Lite interface
  parameter type axi_lite_addr_t = logic [RtAxiLiteAddrWidth-1  :0],
  parameter type axi_lite_data_t = logic [RtAxiLiteDataWidth-1  :0],
  parameter type axi_lite_strb_t = logic [RtAxiLiteDataWidth/8-1:0]
) (
  input logic                         clk_i,
  input logic                         rst_ni,

  // AXI manager ports
  output [ 3:0] [ RtNumManagers-1:0]  m_axi_rt_awid_o,
  output [ 47:0] [ RtNumManagers-1:0] m_axi_rt_awaddr_o,
  output [ 7:0] [ RtNumManagers-1:0]  m_axi_rt_awlen_o,
  output [ 2:0] [ RtNumManagers-1:0]  m_axi_rt_awsize_o,
  output [ 1:0] [ RtNumManagers-1:0]  m_axi_rt_awburst_o,
  output [ 1:0]                       m_axi_rt_awlock_o,
  output [ 3:0] [ RtNumManagers-1:0]  m_axi_rt_awcache_o,
  output [ 2:0] [ RtNumManagers-1:0]  m_axi_rt_awprot_o,
  output [ 3:0] [ RtNumManagers-1:0]  m_axi_rt_awqos_o,
  output [ 3:0] [ RtNumManagers-1:0]  m_axi_rt_awuser_o,
  output [ 1:0]                       m_axi_rt_awvalid_o,
  input [ 1:0]                        m_axi_rt_awready_i,
  output [ 63:0] [ RtNumManagers-1:0] m_axi_rt_wdata_o,
  output [ 7:0] [ RtNumManagers-1:0]  m_axi_rt_wstrb_o,
  output [ 1:0]                       m_axi_rt_wlast_o,
  output [ 1:0]                       m_axi_rt_wvalid_o,
  input [ 1:0]                        m_axi_rt_wready_i,
  input [ 3:0] [ RtNumManagers-1:0]   m_axi_rt_bid_i,
  input [ 1:0] [ RtNumManagers-1:0]   m_axi_rt_bresp_i,
  input [ 1:0]                        m_axi_rt_bvalid_i,
  output [ 1:0]                       m_axi_rt_bready_o,
  output [ 3:0] [ RtNumManagers-1:0]  m_axi_rt_arid_o,
  output [ 47:0] [ RtNumManagers-1:0] m_axi_rt_araddr_o,
  output [ 7:0] [ RtNumManagers-1:0]  m_axi_rt_arlen_o,
  output [ 2:0] [ RtNumManagers-1:0]  m_axi_rt_arsize_o,
  output [ 1:0] [ RtNumManagers-1:0]  m_axi_rt_arburst_o,
  output [ 1:0]                       m_axi_rt_arlock_o,
  output [ 3:0] [ RtNumManagers-1:0]  m_axi_rt_arcache_o,
  output [ 2:0] [ RtNumManagers-1:0]  m_axi_rt_arprot_o,
  output [ 3:0] [ RtNumManagers-1:0]  m_axi_rt_arqos_o,
  output [ 3:0] [ RtNumManagers-1:0]  m_axi_rt_aruser_o,
  output [ 1:0]                       m_axi_rt_arvalid_o,
  input [ 1:0]                        m_axi_rt_arready_i,
  input [ 3:0] [ RtNumManagers-1:0]   m_axi_rt_rid_i,
  input [ 63:0] [ RtNumManagers-1:0]  m_axi_rt_rdata_i,
  input [ 1:0] [ RtNumManagers-1:0]   m_axi_rt_rresp_i,
  input [ 1:0]                        m_axi_rt_rlast_i,
  input [ 1:0]                        m_axi_rt_rvalid_i,
  output [ 1:0]                       m_axi_rt_rready_o,
    
  // AXI subordinate ports
  input [ 3:0] [ RtNumManagers-1:0]   s_axi_rt_awid_i,
  input [ 47:0] [ RtNumManagers-1:0]  s_axi_rt_awaddr_i,
  input [ 7:0] [ RtNumManagers-1:0]   s_axi_rt_awlen_i,
  input [ 2:0] [ RtNumManagers-1:0]   s_axi_rt_awsize_i,
  input [ 1:0] [ RtNumManagers-1:0]   s_axi_rt_awburst_i,
  input [ 1:0]                        s_axi_rt_awlock_i,
  input [ 3:0] [ RtNumManagers-1:0]   s_axi_rt_awcache_i,
  input [ 2:0] [ RtNumManagers-1:0]   s_axi_rt_awprot_i,
  input [ 3:0] [ RtNumManagers-1:0]   s_axi_rt_awqos_i,
  input [ 3:0] [ RtNumManagers-1:0]   s_axi_rt_awuser_i,
  input [ 1:0]                        s_axi_rt_awvalid_i,
  output [ 1:0]                       s_axi_rt_awready_o,
  input [ 63:0] [ RtNumManagers-1:0]  s_axi_rt_wdata_i,
  input [ 7:0] [ RtNumManagers-1:0]   s_axi_rt_wstrb_i,
  input [ 1:0]                        s_axi_rt_wlast_i,
  input [ 1:0]                        s_axi_rt_wvalid_i,
  output [ 1:0]                       s_axi_rt_wready_o,
  output [ 3:0] [ RtNumManagers-1:0]  s_axi_rt_bid_o,
  output [ 1:0] [ RtNumManagers-1:0]  s_axi_rt_bresp_o,
  output [ 1:0]                       s_axi_rt_bvalid_o,
  input [ 1:0]                        s_axi_rt_bready_i,
  input [ 3:0] [ RtNumManagers-1:0]   s_axi_rt_arid_i,
  input [ 47:0] [ RtNumManagers-1:0]  s_axi_rt_araddr_i,
  input [ 7:0] [ RtNumManagers-1:0]   s_axi_rt_arlen_i,
  input [ 2:0] [ RtNumManagers-1:0]   s_axi_rt_arsize_i,
  input [ 1:0] [ RtNumManagers-1:0]   s_axi_rt_arburst_i,
  input [ 1:0]                        s_axi_rt_arlock_i,
  input [ 3:0] [ RtNumManagers-1:0]   s_axi_rt_arcache_i,
  input [ 2:0] [ RtNumManagers-1:0]   s_axi_rt_arprot_i,
  input [ 3:0] [ RtNumManagers-1:0]   s_axi_rt_arqos_i,
  input [ 3:0] [ RtNumManagers-1:0]   s_axi_rt_aruser_i,
  input [ 1:0]                        s_axi_rt_arvalid_i,
  output [ 1:0]                       s_axi_rt_arready_o,
  output [ 3:0] [ RtNumManagers-1:0]  s_axi_rt_rid_o,
  output [ 63:0] [ RtNumManagers-1:0] s_axi_rt_rdata_o,
  output [ 1:0] [ RtNumManagers-1:0]  s_axi_rt_rresp_o,
  output [ 1:0]                       s_axi_rt_rlast_o,
  output [ 1:0]                       s_axi_rt_rvalid_o,
  input [ 1:0]                        s_axi_rt_rready_i,
    
  // AXI-Lite cfg port
  input [ 31:0]                       s_axi_lite_rt_awaddr_i,
  input [ 2:0]                        s_axi_lite_rt_awprot_i,
  input                               s_axi_lite_rt_awvalid_i,
  output                              s_axi_lite_rt_awready_o,
  input [ 31:0]                       s_axi_lite_rt_wdata_i,
  input [ 3:0]                        s_axi_lite_rt_wstrb_i,
  input                               s_axi_lite_rt_wvalid_i,
  output                              s_axi_lite_rt_wready_o,
  output [ 1:0]                       s_axi_lite_rt_bresp_o,
  output                              s_axi_lite_rt_bvalid_o,
  input                               s_axi_lite_rt_bready_i,
  input [ 31:0]                       s_axi_lite_rt_araddr_i,
  input [ 2:0]                        s_axi_lite_rt_arprot_i,
  input                               s_axi_lite_rt_arvalid_i,
  output                              s_axi_lite_rt_arready_o,
  output [ 31:0]                      s_axi_lite_rt_rdata_o,
  output [ 1:0]                       s_axi_lite_rt_rresp_o,
  output                              s_axi_lite_rt_rvalid_o,
  input                               s_axi_lite_rt_rready_i
);

  // Define unused AXI signals for FPGA wrapper
  axi_pkg::region_t m_axi_rt_awregion_o, s_axi_rt_awregion_i, m_axi_rt_arregion_o, s_axi_rt_arregion_i;
  axi_user_t m_axi_rt_wuser_o, m_axi_rt_buser_i, m_axi_rt_ruser_i, s_axi_rt_wuser_i, s_axi_rt_buser_o, s_axi_rt_ruser_o;
  
  // Tie unused inputs to 0, leave output floating
  assign s_axi_rt_awregion_i = '0;
  assign s_axi_rt_arregion_i = '0;  
  assign m_axi_rt_buser_i = '0;  
  assign m_axi_rt_ruser_i = '0;  
  assign s_axi_rt_wuser_i = '0;  

  //localparam type reg_id_t       = logic    [RtRegIdWidth-1    :0];

  // Define AXI struct channels types
  `AXI_TYPEDEF_ALL(axi, axi_addr_t, axi_id_t, axi_data_t, axi_strb_t, axi_user_t)

  axi_req_t  [RtNumManagers-1:0] m_req, s_req;
  axi_resp_t [RtNumManagers-1:0] m_rsp, s_rsp;

  // Connect AXI structs to flatten in/out AXI ports
  `AXI_ASSIGN_MASTER_TO_FLAT_ARRAY(rt, RtNumManagers, m_req, m_rsp)
  `AXI_ASSIGN_SLAVE_TO_FLAT_ARRAY (rt, RtNumManagers, s_req, s_rsp)

  // Define configuration register bus
  `REG_BUS_TYPEDEF_ALL(cfg, axi_lite_addr_t, axi_lite_data_t, axi_lite_strb_t)

  cfg_req_t  cfg_req;
  cfg_rsp_t  cfg_rsp;

  // Define AXI-Lite struct channel types
  `AXI_LITE_TYPEDEF_ALL(axi_lite, axi_lite_addr_t, axi_lite_data_t, axi_lite_strb_t)

  axi_lite_req_t s_lite_req;
  axi_lite_resp_t s_lite_rsp;  

   // Connect AXI Lite structs to flatten config. AXI Lite ports
  `AXI_LITE_ASSIGN_SLAVE_TO_FLAT_ARRAY (rt, 1, s_lite_req, s_lite_rsp)

  // Convert AXI Lite to custom register interface fr RT configuration bus
  axi_lite_to_reg #(
    .ADDR_WIDTH   (RtAxiLiteAddrWidth),
    .DATA_WIDTH   (RtAxiLiteDataWidth),
    .BUFFER_DEPTH (2),
    .DECOUPLE_W   (1),
    .axi_lite_req_t (axi_lite_req_t),
    .axi_lite_rsp_t (axi_lite_resp_t),
    .reg_req_t (cfg_req_t),
    .reg_rsp_t (cfg_rsp_t)
  ) i_axi_lite_to_reg (
    .clk_i,
    .rst_ni,
    .axi_lite_req_i ( s_lite_req ),
    .axi_lite_rsp_o ( s_lite_rsp ),
    .reg_req_o      ( cfg_req ),
    .reg_rsp_i      ( cfg_rsp )
  );

  //-----------------------------------
  // DUT
  //-----------------------------------
  axi_rt_unit_top #(
    .NumManagers    ( RtNumManagers      ),
    .AddrWidth      ( RtAxiAddrWidth     ),
    .DataWidth      ( RtAxiDataWidth     ),
    .IdWidth        ( RtAxiIdWidth       ),
    .UserWidth      ( RtAxiUserWidth     ),
    .NumPending     ( RtNumPending       ),
    .WBufferDepth   ( RtWBufferDepth     ),
    .NumAddrRegions ( RtNumRegions       ),
    .BudgetWidth    ( RtBudgetWidth      ),
    .PeriodWidth    ( RtPeriodWidth      ),
    .RegIdWidth     ( RtRegIdWidth       ),
    .CutSplitterPaths   ( RtCutPaths ),
    .DisableSplitChecks ( !RtEnableChecks ),
    .CutDecErrors   ( RtCutDecErrors     ),
    .aw_chan_t      ( axi_aw_chan_t    ),
    .ar_chan_t      ( axi_ar_chan_t    ),
    .w_chan_t       ( axi_w_chan_t     ),
    .b_chan_t       ( axi_b_chan_t     ),
    .r_chan_t       ( axi_r_chan_t     ),
    .axi_req_t      ( axi_req_t        ),
    .axi_resp_t     ( axi_resp_t       ),
    .req_req_t      ( cfg_req_t        ),
    .req_rsp_t      ( cfg_rsp_t        )
  ) i_axi_rt_unit_top (
    .clk_i,
    .rst_ni,
    .slv_req_i        ( s_req         ),
    .slv_resp_o       ( s_rsp         ),
    .mst_req_o        ( m_req         ),
    .mst_resp_i       ( m_rsp         ),
    .reg_req_i        ( cfg_req       ),
    .reg_rsp_o        ( cfg_rsp       ),
    .reg_id_i         ( '0            ) // Temporary solution
  );

endmodule
