// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Andreas Kurth <adk@lowrisc.org>
// - Alessandro Ottaviano <aottaviano@ethz.ch>
// This file was automatically generated with `rt_gen_xilinx.py`
/// Xilinx Wrapper for the AXI RT unit
module axi_rt_unit_top_xilinx_ip (
    input           clk_i
,
    input           rst_ni
,
    output [  3:0] [  1:0] m_axi_rt_awid_o
,
    output [ 47:0] [  1:0] m_axi_rt_awaddr_o
,
    output [  7:0] [  1:0] m_axi_rt_awlen_o
,
    output [  2:0] [  1:0] m_axi_rt_awsize_o
,
    output [  1:0] [  1:0] m_axi_rt_awburst_o
,
    output [  1:0]  m_axi_rt_awlock_o
,
    output [  3:0] [  1:0] m_axi_rt_awcache_o
,
    output [  2:0] [  1:0] m_axi_rt_awprot_o
,
    output [  3:0] [  1:0] m_axi_rt_awqos_o
,
    output [  3:0] [  1:0] m_axi_rt_awuser_o
,
    output [  1:0]  m_axi_rt_awvalid_o
,
    input  [  1:0]  m_axi_rt_awready_i
,
    output [ 63:0] [  1:0] m_axi_rt_wdata_o
,
    output [  7:0] [  1:0] m_axi_rt_wstrb_o
,
    output [  1:0]  m_axi_rt_wlast_o
,
    output [  1:0]  m_axi_rt_wvalid_o
,
    input  [  1:0]  m_axi_rt_wready_i
,
    input  [  3:0] [  1:0] m_axi_rt_bid_i
,
    input  [  1:0] [  1:0] m_axi_rt_bresp_i
,
    input  [  1:0]  m_axi_rt_bvalid_i
,
    output [  1:0]  m_axi_rt_bready_o
,
    output [  3:0] [  1:0] m_axi_rt_arid_o
,
    output [ 47:0] [  1:0] m_axi_rt_araddr_o
,
    output [  7:0] [  1:0] m_axi_rt_arlen_o
,
    output [  2:0] [  1:0] m_axi_rt_arsize_o
,
    output [  1:0] [  1:0] m_axi_rt_arburst_o
,
    output [  1:0]  m_axi_rt_arlock_o
,
    output [  3:0] [  1:0] m_axi_rt_arcache_o
,
    output [  2:0] [  1:0] m_axi_rt_arprot_o
,
    output [  3:0] [  1:0] m_axi_rt_arqos_o
,
    output [  3:0] [  1:0] m_axi_rt_aruser_o
,
    output [  1:0]  m_axi_rt_arvalid_o
,
    input  [  1:0]  m_axi_rt_arready_i
,
    input  [  3:0] [  1:0] m_axi_rt_rid_i
,
    input  [ 63:0] [  1:0] m_axi_rt_rdata_i
,
    input  [  1:0] [  1:0] m_axi_rt_rresp_i
,
    input  [  1:0]  m_axi_rt_rlast_i
,
    input  [  1:0]  m_axi_rt_rvalid_i
,
    output [  1:0]  m_axi_rt_rready_o
,
    input  [  3:0] [  1:0] s_axi_rt_awid_i
,
    input  [ 47:0] [  1:0] s_axi_rt_awaddr_i
,
    input  [  7:0] [  1:0] s_axi_rt_awlen_i
,
    input  [  2:0] [  1:0] s_axi_rt_awsize_i
,
    input  [  1:0] [  1:0] s_axi_rt_awburst_i
,
    input  [  1:0]  s_axi_rt_awlock_i
,
    input  [  3:0] [  1:0] s_axi_rt_awcache_i
,
    input  [  2:0] [  1:0] s_axi_rt_awprot_i
,
    input  [  3:0] [  1:0] s_axi_rt_awqos_i
,
    input  [  3:0] [  1:0] s_axi_rt_awuser_i
,
    input  [  1:0]  s_axi_rt_awvalid_i
,
    output [  1:0]  s_axi_rt_awready_o
,
    input  [ 63:0] [  1:0] s_axi_rt_wdata_i
,
    input  [  7:0] [  1:0] s_axi_rt_wstrb_i
,
    input  [  1:0]  s_axi_rt_wlast_i
,
    input  [  1:0]  s_axi_rt_wvalid_i
,
    output [  1:0]  s_axi_rt_wready_o
,
    output [  3:0] [  1:0] s_axi_rt_bid_o
,
    output [  1:0] [  1:0] s_axi_rt_bresp_o
,
    output [  1:0]  s_axi_rt_bvalid_o
,
    input  [  1:0]  s_axi_rt_bready_i
,
    input  [  3:0] [  1:0] s_axi_rt_arid_i
,
    input  [ 47:0] [  1:0] s_axi_rt_araddr_i
,
    input  [  7:0] [  1:0] s_axi_rt_arlen_i
,
    input  [  2:0] [  1:0] s_axi_rt_arsize_i
,
    input  [  1:0] [  1:0] s_axi_rt_arburst_i
,
    input  [  1:0]  s_axi_rt_arlock_i
,
    input  [  3:0] [  1:0] s_axi_rt_arcache_i
,
    input  [  2:0] [  1:0] s_axi_rt_arprot_i
,
    input  [  3:0] [  1:0] s_axi_rt_arqos_i
,
    input  [  3:0] [  1:0] s_axi_rt_aruser_i
,
    input  [  1:0]  s_axi_rt_arvalid_i
,
    output [  1:0]  s_axi_rt_arready_o
,
    output [  3:0] [  1:0] s_axi_rt_rid_o
,
    output [ 63:0] [  1:0] s_axi_rt_rdata_o
,
    output [  1:0] [  1:0] s_axi_rt_rresp_o
,
    output [  1:0]  s_axi_rt_rlast_o
,
    output [  1:0]  s_axi_rt_rvalid_o
,
    input  [  1:0]  s_axi_rt_rready_i
,
    input  [ 31:0]  s_axi_lite_rt_awaddr_i
,
    input  [  2:0]  s_axi_lite_rt_awprot_i
,
    input           s_axi_lite_rt_awvalid_i
,
    output          s_axi_lite_rt_awready_o
,
    input  [ 31:0]  s_axi_lite_rt_wdata_i
,
    input  [  3:0]  s_axi_lite_rt_wstrb_i
,
    input           s_axi_lite_rt_wvalid_i
,
    output          s_axi_lite_rt_wready_o
,
    output [  1:0]  s_axi_lite_rt_bresp_o
,
    output          s_axi_lite_rt_bvalid_o
,
    input           s_axi_lite_rt_bready_i
,
    input  [ 31:0]  s_axi_lite_rt_araddr_i
,
    input  [  2:0]  s_axi_lite_rt_arprot_i
,
    input           s_axi_lite_rt_arvalid_i
,
    output          s_axi_lite_rt_arready_o
,
    output [ 31:0]  s_axi_lite_rt_rdata_o
,
    output [  1:0]  s_axi_lite_rt_rresp_o
,
    output          s_axi_lite_rt_rvalid_o
,
    input           s_axi_lite_rt_rready_i
);
  // Number of managers
  localparam RtNumManagers  = 2;
  // Number of regions per manager
  localparam RtNumRegions   = 1;
  // Number of outstanding transactions
  localparam RtNumPending   = 32;
  // Depth of the Buffer
  localparam RtWBufferDepth = 32;
  // Period width
  localparam RtPeriodWidth  = 32;
  // Budget width
  localparam RtBudgetWidth  = 32;
  // Enable internal cuts in the RT units
  localparam RtCutPaths     = 1;
  // Enable transaction checks within the RT units
  localparam RtEnableChecks = 0;
  // Enable internal cuts (a flop) for decode errors
  localparam RtCutDecErrors = 0;
  // AXI configuration
  localparam RtAxiIdWidth   = 4;
  localparam RtAxiAddrWidth = 48;
  localparam RtAxiDataWidth = 64;
  localparam RtAxiUserWidth = 4;
  // AXI Lite configuration
  localparam RtAxiLiteAddrWidth = 32;
  localparam RtAxiLiteDataWidth = 32;
  // Register configuration
  localparam RtRegIdWidth   = 5;
  // AXI RT unit, xilinx wrapper
  axi_rt_unit_top_xilinx #(
    .RtNumManagers      ( RtNumManagers      ),
    .RtNumRegions   	( RtNumRegions	     ),
    .RtNumPending   	( RtNumPending	     ),
    .RtWBufferDepth 	( RtWBufferDepth     ),
    .RtPeriodWidth  	( RtPeriodWidth      ),
    .RtBudgetWidth  	( RtBudgetWidth      ),
    .RtCutPaths     	( RtCutPaths	     ),
    .RtEnableChecks 	( RtEnableChecks     ),
    .RtCutDecErrors     ( RtCutDecErrors     ),
    .RtAxiIdWidth   	( RtAxiIdWidth	     ),
    .RtAxiAddrWidth 	( RtAxiAddrWidth     ),
    .RtAxiDataWidth 	( RtAxiDataWidth     ),
    .RtAxiUserWidth 	( RtAxiUserWidth     ),
    .RtAxiLiteAddrWidth	( RtAxiLiteAddrWidth ),
    .RtAxiLiteDataWidth	( RtAxiLiteDataWidth ),
    .RtRegIdWidth       ( RtRegIdWidth       )
  ) i_axi_rt_unit_top_xilinx (
    .clk_i (clk_i)
,
    .rst_ni (rst_ni)
,
    .m_axi_rt_awid_o (m_axi_rt_awid_o)
,
    .m_axi_rt_awaddr_o (m_axi_rt_awaddr_o)
,
    .m_axi_rt_awlen_o (m_axi_rt_awlen_o)
,
    .m_axi_rt_awsize_o (m_axi_rt_awsize_o)
,
    .m_axi_rt_awburst_o (m_axi_rt_awburst_o)
,
    .m_axi_rt_awlock_o (m_axi_rt_awlock_o)
,
    .m_axi_rt_awcache_o (m_axi_rt_awcache_o)
,
    .m_axi_rt_awprot_o (m_axi_rt_awprot_o)
,
    .m_axi_rt_awqos_o (m_axi_rt_awqos_o)
,
    .m_axi_rt_awuser_o (m_axi_rt_awuser_o)
,
    .m_axi_rt_awvalid_o (m_axi_rt_awvalid_o)
,
    .m_axi_rt_awready_i (m_axi_rt_awready_i)
,
    .m_axi_rt_wdata_o (m_axi_rt_wdata_o)
,
    .m_axi_rt_wstrb_o (m_axi_rt_wstrb_o)
,
    .m_axi_rt_wlast_o (m_axi_rt_wlast_o)
,
    .m_axi_rt_wvalid_o (m_axi_rt_wvalid_o)
,
    .m_axi_rt_wready_i (m_axi_rt_wready_i)
,
    .m_axi_rt_bid_i (m_axi_rt_bid_i)
,
    .m_axi_rt_bresp_i (m_axi_rt_bresp_i)
,
    .m_axi_rt_bvalid_i (m_axi_rt_bvalid_i)
,
    .m_axi_rt_bready_o (m_axi_rt_bready_o)
,
    .m_axi_rt_arid_o (m_axi_rt_arid_o)
,
    .m_axi_rt_araddr_o (m_axi_rt_araddr_o)
,
    .m_axi_rt_arlen_o (m_axi_rt_arlen_o)
,
    .m_axi_rt_arsize_o (m_axi_rt_arsize_o)
,
    .m_axi_rt_arburst_o (m_axi_rt_arburst_o)
,
    .m_axi_rt_arlock_o (m_axi_rt_arlock_o)
,
    .m_axi_rt_arcache_o (m_axi_rt_arcache_o)
,
    .m_axi_rt_arprot_o (m_axi_rt_arprot_o)
,
    .m_axi_rt_arqos_o (m_axi_rt_arqos_o)
,
    .m_axi_rt_aruser_o (m_axi_rt_aruser_o)
,
    .m_axi_rt_arvalid_o (m_axi_rt_arvalid_o)
,
    .m_axi_rt_arready_i (m_axi_rt_arready_i)
,
    .m_axi_rt_rid_i (m_axi_rt_rid_i)
,
    .m_axi_rt_rdata_i (m_axi_rt_rdata_i)
,
    .m_axi_rt_rresp_i (m_axi_rt_rresp_i)
,
    .m_axi_rt_rlast_i (m_axi_rt_rlast_i)
,
    .m_axi_rt_rvalid_i (m_axi_rt_rvalid_i)
,
    .m_axi_rt_rready_o (m_axi_rt_rready_o)
,
    .s_axi_rt_awid_i (s_axi_rt_awid_i)
,
    .s_axi_rt_awaddr_i (s_axi_rt_awaddr_i)
,
    .s_axi_rt_awlen_i (s_axi_rt_awlen_i)
,
    .s_axi_rt_awsize_i (s_axi_rt_awsize_i)
,
    .s_axi_rt_awburst_i (s_axi_rt_awburst_i)
,
    .s_axi_rt_awlock_i (s_axi_rt_awlock_i)
,
    .s_axi_rt_awcache_i (s_axi_rt_awcache_i)
,
    .s_axi_rt_awprot_i (s_axi_rt_awprot_i)
,
    .s_axi_rt_awqos_i (s_axi_rt_awqos_i)
,
    .s_axi_rt_awuser_i (s_axi_rt_awuser_i)
,
    .s_axi_rt_awvalid_i (s_axi_rt_awvalid_i)
,
    .s_axi_rt_awready_o (s_axi_rt_awready_o)
,
    .s_axi_rt_wdata_i (s_axi_rt_wdata_i)
,
    .s_axi_rt_wstrb_i (s_axi_rt_wstrb_i)
,
    .s_axi_rt_wlast_i (s_axi_rt_wlast_i)
,
    .s_axi_rt_wvalid_i (s_axi_rt_wvalid_i)
,
    .s_axi_rt_wready_o (s_axi_rt_wready_o)
,
    .s_axi_rt_bid_o (s_axi_rt_bid_o)
,
    .s_axi_rt_bresp_o (s_axi_rt_bresp_o)
,
    .s_axi_rt_bvalid_o (s_axi_rt_bvalid_o)
,
    .s_axi_rt_bready_i (s_axi_rt_bready_i)
,
    .s_axi_rt_arid_i (s_axi_rt_arid_i)
,
    .s_axi_rt_araddr_i (s_axi_rt_araddr_i)
,
    .s_axi_rt_arlen_i (s_axi_rt_arlen_i)
,
    .s_axi_rt_arsize_i (s_axi_rt_arsize_i)
,
    .s_axi_rt_arburst_i (s_axi_rt_arburst_i)
,
    .s_axi_rt_arlock_i (s_axi_rt_arlock_i)
,
    .s_axi_rt_arcache_i (s_axi_rt_arcache_i)
,
    .s_axi_rt_arprot_i (s_axi_rt_arprot_i)
,
    .s_axi_rt_arqos_i (s_axi_rt_arqos_i)
,
    .s_axi_rt_aruser_i (s_axi_rt_aruser_i)
,
    .s_axi_rt_arvalid_i (s_axi_rt_arvalid_i)
,
    .s_axi_rt_arready_o (s_axi_rt_arready_o)
,
    .s_axi_rt_rid_o (s_axi_rt_rid_o)
,
    .s_axi_rt_rdata_o (s_axi_rt_rdata_o)
,
    .s_axi_rt_rresp_o (s_axi_rt_rresp_o)
,
    .s_axi_rt_rlast_o (s_axi_rt_rlast_o)
,
    .s_axi_rt_rvalid_o (s_axi_rt_rvalid_o)
,
    .s_axi_rt_rready_i (s_axi_rt_rready_i)
,
    .s_axi_lite_rt_awaddr_i (s_axi_lite_rt_awaddr_i)
,
    .s_axi_lite_rt_awprot_i (s_axi_lite_rt_awprot_i)
,
    .s_axi_lite_rt_awvalid_i (s_axi_lite_rt_awvalid_i)
,
    .s_axi_lite_rt_awready_o (s_axi_lite_rt_awready_o)
,
    .s_axi_lite_rt_wdata_i (s_axi_lite_rt_wdata_i)
,
    .s_axi_lite_rt_wstrb_i (s_axi_lite_rt_wstrb_i)
,
    .s_axi_lite_rt_wvalid_i (s_axi_lite_rt_wvalid_i)
,
    .s_axi_lite_rt_wready_o (s_axi_lite_rt_wready_o)
,
    .s_axi_lite_rt_bresp_o (s_axi_lite_rt_bresp_o)
,
    .s_axi_lite_rt_bvalid_o (s_axi_lite_rt_bvalid_o)
,
    .s_axi_lite_rt_bready_i (s_axi_lite_rt_bready_i)
,
    .s_axi_lite_rt_araddr_i (s_axi_lite_rt_araddr_i)
,
    .s_axi_lite_rt_arprot_i (s_axi_lite_rt_arprot_i)
,
    .s_axi_lite_rt_arvalid_i (s_axi_lite_rt_arvalid_i)
,
    .s_axi_lite_rt_arready_o (s_axi_lite_rt_arready_o)
,
    .s_axi_lite_rt_rdata_o (s_axi_lite_rt_rdata_o)
,
    .s_axi_lite_rt_rresp_o (s_axi_lite_rt_rresp_o)
,
    .s_axi_lite_rt_rvalid_o (s_axi_lite_rt_rvalid_o)
,
    .s_axi_lite_rt_rready_i (s_axi_lite_rt_rready_i)
  );
endmodule
