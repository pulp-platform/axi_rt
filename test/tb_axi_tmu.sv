// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Chaoqun Liang <chaoqun.liang@unibo.it>

`include "axi/assign.svh"
`include "axi/typedef.svh"
`include "register_interface/assign.svh"
`include "register_interface/typedef.svh"

module tb_axi_tmu;
  import axi_pkg::*;
  import axi_tmu_pkg::*;

  // TMU parameters
  parameter int unsigned TbMaxUniqIds    = 16;
  parameter int unsigned TbMaxTxnsPerId  = 64;
  parameter int unsigned TbMaxWrTxns     = 32;
  parameter int unsigned TbMaxRdTxns     = 32;

  parameter int unsigned TbCounterWidth  = 10;
  parameter int unsigned TbHsCntWidth    = 8;
  parameter int unsigned TbPrescalerDiv  = 1;
  // AXI parameters
  parameter int unsigned TbAxiAddrWidth  = 32;
  parameter int unsigned TbAxiDataWidth  = 32;
  parameter int unsigned TbAxiIdWidth    = 6;
  parameter int unsigned TbAxiIntIdWidth = (TbMaxUniqIds > 1) ? $clog2(TbMaxUniqIds) : 1;
  parameter int unsigned TbAxiUserWidth  = 1;
  parameter int unsigned TbAxiLogDepth   = 1;

  parameter bit TbEnAtop                 = 1'b0;
  parameter bit TbEnExcl                 = 1'b0;
  parameter bit TbUniqueIds              = 1'b0;

  // Testbench timing
  localparam time CyclTime               = 10ns;
  localparam time ApplTime               = 2ns;
  localparam time TestTime               = 8ns;

  typedef axi_test::axi_rand_master #(
    .AW                   ( TbAxiAddrWidth  ),
    .DW                   ( TbAxiDataWidth  ),
    .IW                   ( TbAxiIdWidth    ),
    .UW                   ( TbAxiUserWidth  ),
    .TA                   ( ApplTime        ),
    .TT                   ( TestTime        ),
    .MAX_READ_TXNS        ( 16              ),
    .MAX_WRITE_TXNS       ( 16              ),
    .AXI_EXCLS            ( TbEnExcl        ),
    .AXI_ATOPS            ( TbEnAtop        ),
    .UNIQUE_IDS           ( TbUniqueIds     ),
    .AX_MIN_WAIT_CYCLES   ( 0               ),
    .AX_MAX_WAIT_CYCLES   ( 0               ),
    .W_MIN_WAIT_CYCLES    ( 0               ),
    .W_MAX_WAIT_CYCLES    ( 0               ),
    .RESP_MIN_WAIT_CYCLES ( 0               ),
    .RESP_MAX_WAIT_CYCLES ( 0               )
  ) axi_rand_mgr_t;

  typedef axi_test::axi_rand_slave #(
    .AW                   ( TbAxiAddrWidth  ),
    .DW                   ( TbAxiDataWidth  ),
    .IW                   ( TbAxiIntIdWidth ),
    .UW                   ( TbAxiUserWidth  ),
    .TA                   ( ApplTime        ),
    .TT                   ( TestTime        ),
    .MAPPED               ( 1'b1            ),
    .AX_MIN_WAIT_CYCLES   ( 0               ),
    .AX_MAX_WAIT_CYCLES   ( 0               ),
    .R_MIN_WAIT_CYCLES    ( 0               ),
    .R_MAX_WAIT_CYCLES    ( 0               ),
    .RESP_MIN_WAIT_CYCLES ( 0               ),
    .RESP_MAX_WAIT_CYCLES ( 0               )
  ) axi_rand_sbr_t;

  logic clk;
  logic rst_n;
  logic reg_error;
  logic irq, rst_stat;
  logic reset_clear;

  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth ),
    .AXI_ID_WIDTH   ( TbAxiIdWidth   ),
    .AXI_USER_WIDTH ( TbAxiUserWidth )
  ) mgr_bus_dv(clk);

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth ),
    .AXI_ID_WIDTH   ( TbAxiIdWidth   ),
    .AXI_USER_WIDTH ( TbAxiUserWidth )
  ) mgr_bus();

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth  ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth  ),
    .AXI_ID_WIDTH   ( TbAxiIntIdWidth ),
    .AXI_USER_WIDTH ( TbAxiUserWidth  )
  ) sbr_bus();

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth  ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth  ),
    .AXI_ID_WIDTH   ( TbAxiIntIdWidth ),
    .AXI_USER_WIDTH ( TbAxiUserWidth  )
  ) sbr_bus_xbar();

  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth  ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth  ),
    .AXI_ID_WIDTH   ( TbAxiIntIdWidth ),
    .AXI_USER_WIDTH ( TbAxiUserWidth  )
  ) sbr_bus_xbar_dv(clk);

  typedef reg_test::reg_driver #(
    .AW ( 32       ),
    .DW ( 32       ),
    .TA ( ApplTime ),
    .TT ( TestTime )
  ) reg_drv_t;

  REG_BUS #(
    .ADDR_WIDTH ( 32 ),
    .DATA_WIDTH ( 32 )
  ) reg_bus (clk);

  typedef logic [TbAxiAddrWidth-1:0]   addr_t;
  typedef logic [TbAxiDataWidth-1:0]   data_t;
  typedef logic [TbAxiDataWidth/8-1:0] strb_t;
  typedef logic [TbAxiIdWidth-1:0]     id_t;
  typedef logic [TbAxiIntIdWidth-1:0]  int_id_t;
  typedef logic [TbAxiUserWidth-1:0]   user_t;

  `AXI_TYPEDEF_AW_CHAN_T(aw_chan_t, addr_t, id_t, user_t);
  `AXI_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t, user_t);
  `AXI_TYPEDEF_B_CHAN_T(b_chan_t, id_t, user_t);
  `AXI_TYPEDEF_AR_CHAN_T(ar_chan_t, addr_t, id_t, user_t);
  `AXI_TYPEDEF_R_CHAN_T(r_chan_t, data_t, id_t, user_t);
  `AXI_TYPEDEF_REQ_T(mgr_req_t, aw_chan_t, w_chan_t, ar_chan_t);
  `AXI_TYPEDEF_RESP_T(mgr_resp_t, b_chan_t, r_chan_t );

  `AXI_TYPEDEF_AW_CHAN_T(int_aw_t, addr_t, int_id_t, user_t);
  `AXI_TYPEDEF_W_CHAN_T(w_t, data_t, strb_t, user_t);
  `AXI_TYPEDEF_B_CHAN_T(int_b_t, int_id_t, user_t);
  `AXI_TYPEDEF_AR_CHAN_T(int_ar_t, addr_t, int_id_t, user_t);
  `AXI_TYPEDEF_R_CHAN_T(int_r_t, data_t, int_id_t, user_t);
  `AXI_TYPEDEF_REQ_T(sbr_req_t, int_aw_t, w_t, int_ar_t);
  `AXI_TYPEDEF_RESP_T(sbr_resp_t, int_b_t, int_r_t );

  mgr_req_t  mgr_req;
  mgr_resp_t mgr_rsp;
  sbr_req_t  sbr_req;
  sbr_resp_t sbr_rsp;

  `AXI_ASSIGN (mgr_bus, mgr_bus_dv)
  `AXI_ASSIGN_TO_REQ(mgr_req, mgr_bus)
  `AXI_ASSIGN_FROM_RESP(mgr_bus, mgr_rsp)

  `AXI_ASSIGN (sbr_bus_xbar_dv, sbr_bus_xbar)
  `AXI_ASSIGN_FROM_REQ(sbr_bus, sbr_req)
  `AXI_ASSIGN_TO_RESP(sbr_rsp, sbr_bus)

  localparam axi_pkg::xbar_cfg_t xbar_cfg = '{
    NoSlvPorts:         1,
    NoMstPorts:         1,
    MaxMstTrans:        8,
    MaxSlvTrans:        8,
    FallThrough:        1'b0,
    LatencyMode:        axi_pkg::CUT_ALL_AX,
    PipelineStages:     0,
    AxiIdWidthSlvPorts: TbAxiIntIdWidth,
    AxiIdUsedSlvPorts:  TbAxiIntIdWidth,
    UniqueIds:          TbUniqueIds,
    AxiAddrWidth:       TbAxiAddrWidth,
    AxiDataWidth:       TbAxiDataWidth,
    NoAddrRules:        1
  };

  typedef axi_pkg::xbar_rule_32_t rule_t;
  localparam rule_t [xbar_cfg.NoAddrRules-1:0] AddrMap = '{
    '{ idx: 0, start_addr: 32'h0000_0000,
       end_addr:   32'hffff_ffff,
       default: '0 }
  };

  axi_xbar_intf #(
    .AXI_USER_WIDTH ( TbAxiUserWidth ),
    .Cfg            ( xbar_cfg       ),
    .rule_t         ( rule_t         )
  ) i_sbr_xbar (
    .clk_i                 ( clk              ),
    .rst_ni                ( rst_n            ),
    .test_i                ( 1'b0             ),
    .slv_ports             ( '{ sbr_bus     } ),
    .mst_ports             ( '{ sbr_bus_xbar} ),
    .addr_map_i            ( AddrMap          ),
    .en_default_mst_port_i ( '0               ),
    .default_mst_port_i    ( '0               )
  );

  `REG_BUS_TYPEDEF_ALL(cfg, logic [31:0], logic [31:0], logic [7:0]);

  cfg_req_t reg_req;
  cfg_rsp_t reg_rsp;

  `REG_BUS_ASSIGN_TO_REQ(reg_req, reg_bus)
  `REG_BUS_ASSIGN_FROM_RSP(reg_bus, reg_rsp)

  clk_rst_gen #(
    .ClkPeriod    ( CyclTime ),
    .RstClkCycles ( 5        )
  ) i_clk_gen (
    .clk_o        ( clk      ),
    .rst_no       ( rst_n    )
  );

  //-----------------------------------
  // DUT (CLT Top)
  //-----------------------------------
  axi_tmu_top #(
    .MaxUniqIds   ( TbMaxUniqIds   ),
    .MaxTxnsPerId ( TbMaxTxnsPerId ),
    .MaxWrTxns    ( TbMaxWrTxns    ),
    .MaxRdTxns    ( TbMaxRdTxns    ),
    .AxiIdWidth   ( TbAxiIdWidth   ),
    .HsCntWidth   ( TbHsCntWidth   ),
    .PrescalerDiv ( TbPrescalerDiv ),
    .mgr_req_t    ( mgr_req_t      ),
    .mgr_rsp_t    ( mgr_resp_t     ),
    .sbr_req_t    ( sbr_req_t      ),
    .sbr_rsp_t    ( sbr_resp_t     ),
    .cfg_req_t    ( cfg_req_t      ),
    .cfg_rsp_t    ( cfg_rsp_t      )
  ) i_axi_tmu (
    .clk_i          ( clk          ),
    .rst_ni         ( rst_n        ),
    .mgr_req_i      ( mgr_req      ),
    .mgr_rsp_o      ( mgr_rsp      ),
    .sbr_req_o      ( sbr_req      ),
    .sbr_rsp_i      ( sbr_rsp      ),
    .cfg_req_i      ( reg_req      ),
    .cfg_rsp_o      ( reg_rsp      ),
    .fault_o        ( irq          ),
    .rst_req_o      ( rst_stat     ),
    .reset_clear_i  ( reset_clear  )
  );

  // -------------------------------
  // AXI Rand Mgr, Sbr & Test Sequence
  // -------------------------------
  logic end_of_sim;
  logic tmu_config;
  axi_rand_mgr_t axi_rand_mgr;
  axi_rand_sbr_t axi_rand_sbr;

  initial begin
    axi_rand_sbr = new(sbr_bus_xbar_dv);
    axi_rand_sbr.reset();
    @(posedge rst_n);
    wait(tmu_config);
    axi_rand_sbr.run();
  end

  initial begin
    automatic reg_drv_t reg_drv = new(reg_bus);
    logic [31:0] rdata;

    axi_rand_mgr = new(mgr_bus_dv);
    end_of_sim   <= 1'b0;
    tmu_config   <= 1'b0;
    reg_error    <= 1'b0;
    reset_clear  <= 1'b0;

    axi_rand_mgr.add_memory_region(32'h0000_0000, 32'h1000_0000, axi_pkg::DEVICE_NONBUFFERABLE);
    axi_rand_mgr.reset();
    reg_drv.reset_master();

    @(posedge rst_n);
    @(posedge clk);

    // -------------------------------------------------------------------------
    // Configure 4 CLT Budgets via REG_BUS (Offsets 0x00, 0x04, 0x08, 0x0c)
    // -------------------------------------------------------------------------
    reg_drv.send_write(32'h0000_0000, 32'h0000_0010, 4'hf, reg_error); // budget_avld_ardy
    reg_drv.send_write(32'h0000_0004, 32'h0000_00ff, 4'hf, reg_error); // budget_w_liveness
    reg_drv.send_write(32'h0000_0008, 32'h0000_0020, 4'hf, reg_error); // budget_b
    reg_drv.send_write(32'h0000_000c, 32'h0000_00ff, 4'hf, reg_error); // budget_r_liveness

    tmu_config <= 1'b1;
    repeat (5) @(posedge clk);

    // -------------------------------------------------------------------------
    // Phase 1: Normal Traffic (9 Reads, 9 Writes)
    // -------------------------------------------------------------------------
    $display("[TB] Starting CLT Phase 1: Normal Traffic (9 Reads, 9 Writes)...");
    axi_rand_mgr.run(9, 9);
    repeat (20) @(posedge clk);

    assert (!irq && !rst_stat)
      else $error("[TB] Unexpected fault during CLT normal traffic! irq=%0b rst_stat=%0b", irq, rst_stat);
    $display("[TB] CLT Phase 1 Passed! No false timeouts.");

    // -------------------------------------------------------------------------
    // Phase 2: Fault Injection (Subordinate BVALID/RVALID Hang) & Cut-and-Drain
    // -------------------------------------------------------------------------
    $display("[TB] Starting CLT Phase 2: Injecting Subordinate Hang (forcing b_valid=0, r_valid=0)...");
    force sbr_rsp.b_valid = 1'b0;
    force sbr_rsp.r_valid = 1'b0;

    axi_rand_mgr.run(4, 4);
    repeat (10) @(posedge clk);

    assert (irq && rst_stat)
      else $error("[TB] Expected fault_o (irq) and rst_req_o (rst_stat) on CLT timeout!");

    reg_drv.send_read(32'h0000_0014, rdata, reg_error); // Read fault_log CSR (0x14 in CLT)
    $display("[TB] CLT Cut-and-Drain Completed! fault_log CSR = 0x%08x (valid=%0b, type=%0d, dir=%0b, phase=%0d)",
             rdata, rdata[0], rdata[3:1], rdata[4], rdata[8:5]);

    // Release hang and pulse reset_clear
    release sbr_rsp.b_valid;
    release sbr_rsp.r_valid;
    reset_clear <= 1'b1;
    @(posedge clk);
    reset_clear <= 1'b0;
    repeat (5) @(posedge clk);

    assert (!irq && !rst_stat)
      else $error("[TB] Expected CLT fault state to clear after reset_clear_i!");
    $display("[TB] CLT Recovery verified! All tests passed.");

    end_of_sim <= 1'b1;
    repeat (10) @(posedge clk);
    $finish();
  end

  // ---------------------------------------------------------------------------
  // Passive Bus Scoreboard: Count actual OKAY vs. fabricated SLVERR completions
  // ---------------------------------------------------------------------------
  int unsigned okay_b_cnt     = 0, slverr_b_cnt     = 0;
  int unsigned okay_rlast_cnt = 0, slverr_rlast_cnt = 0;
  int unsigned total_r_beats  = 0, total_w_beats    = 0;

  always @(posedge clk) begin
    if (rst_n) begin
      if (mgr_req.w_valid && mgr_rsp.w_ready) begin
        total_w_beats++;
      end
      if (mgr_rsp.b_valid && mgr_req.b_ready) begin
        if (mgr_rsp.b.resp == axi_pkg::RESP_OKAY)   okay_b_cnt++;
        if (mgr_rsp.b.resp == axi_pkg::RESP_SLVERR) slverr_b_cnt++;
      end
      if (mgr_rsp.r_valid && mgr_req.r_ready) begin
        total_r_beats++;
        if (mgr_rsp.r.last) begin
          if (mgr_rsp.r.resp == axi_pkg::RESP_OKAY)   okay_rlast_cnt++;
          if (mgr_rsp.r.resp == axi_pkg::RESP_SLVERR) slverr_rlast_cnt++;
        end
      end
    end
  end

  final begin
    $display("==========================================================");
    $display("[CLT SCOREBOARD] Total W beats transferred : %0d", total_w_beats);
    $display("[CLT SCOREBOARD] Total R beats transferred : %0d", total_r_beats);
    $display("[CLT SCOREBOARD] Write B completions       : %0d OKAY, %0d SLVERR (Total=%0d/13)",
             okay_b_cnt, slverr_b_cnt, okay_b_cnt + slverr_b_cnt);
    $display("[CLT SCOREBOARD] Read RLAST completions    : %0d OKAY, %0d SLVERR (Total=%0d/13)",
             okay_rlast_cnt, slverr_rlast_cnt, okay_rlast_cnt + slverr_rlast_cnt);
    $display("==========================================================");
    assert ((okay_b_cnt + slverr_b_cnt) == 13)
      else $error("Missing write completions!");
    assert ((okay_rlast_cnt + slverr_rlast_cnt) == 13)
      else $error("Missing read completions!");
    assert (slverr_b_cnt == 4 && slverr_rlast_cnt == 4)
      else $error("Expected 4 fabricated SLVERR writes and 4 fabricated SLVERR reads!");
  end

endmodule
  
