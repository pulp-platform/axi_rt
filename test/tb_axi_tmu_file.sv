
`include "axi/assign.svh"
`include "axi/typedef.svh"
`include "register_interface/assign.svh"
`include "register_interface/typedef.svh"

/// Testbench for the slave monitring unit
module tb_axi_tmu;
  // TMU parameters
  parameter int unsigned TbMaxUniqIds    = 16;
  parameter int unsigned TbMaxTxnsPerId  = 2;
  parameter int unsigned TbMaxWrTxns     = 16;
  parameter int unsigned TbMaxRdTxns     = 16;

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
  /// Number of write transactions per manager.
  parameter int unsigned TbNumWrites     = 32'd10;
  /// Number of read transactions per manager.
  parameter int unsigned TbNumReads      = 32'd10;

  parameter bit TbEnAtop                 = 1'b0;
  parameter bit TbEnExcl                 = 1'b0;
  /// Restrict to only unique IDs
  parameter bit TbUniqueIds              = 1'b0;
  /// Testbench timing
  parameter time CyclTime                = 10ns;
  parameter time ApplTime                = 2ns;
  parameter time TestTime                = 8ns;

  typedef axi_test::axi_file_master#(
    .AW ( TbAxiAddrWidth          ),
    .DW ( TbAxiDataWidth          ),
    .IW ( TbAxiIdWidth            ),
    .UW ( TbAxiUserWidth          ),
    .TA                   ( ApplTime       ),
    .TT                   ( TestTime       )
  ) axi_file_master_t;

  typedef axi_test::axi_driver #(
    .AW ( TbAxiAddrWidth          ),
    .DW ( TbAxiDataWidth          ),
    .IW ( TbAxiIdWidth            ),
    .UW ( TbAxiUserWidth          ),
    .TA( ApplTime       ),
    .TT( TestTime       )
  ) axi_drv_t;

  // -------------
  // DUT signals
  // -------------
  logic clk;
  logic rst_n;
  logic reg_error;
  logic irq, rst_stat;

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth ),
    .AXI_ID_WIDTH   ( TbAxiIdWidth   ),
    .AXI_USER_WIDTH ( TbAxiUserWidth )
  ) master();

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth ),
    .AXI_ID_WIDTH   ( TbAxiIntIdWidth   ),
    .AXI_USER_WIDTH ( TbAxiUserWidth )
  ) slave();

  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth ),
    .AXI_ID_WIDTH   ( TbAxiIdWidth   ),
    .AXI_USER_WIDTH ( TbAxiUserWidth )
  ) master_dv(clk);

  AXI_BUS_DV #(
   .AXI_ADDR_WIDTH ( TbAxiAddrWidth ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth ),
    .AXI_ID_WIDTH   ( TbAxiIntIdWidth   ),
    .AXI_USER_WIDTH ( TbAxiUserWidth )
  ) slave_dv(clk);

  typedef reg_test::reg_driver #(
    .AW ( 32        ),
    .DW ( 32        ),
    .TA ( ApplTime  ),
    .TT ( TestTime  )
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
  `AXI_TYPEDEF_REQ_T(mst_req_t, aw_chan_t, w_chan_t, ar_chan_t);
  `AXI_TYPEDEF_RESP_T(mst_resp_t, b_chan_t, r_chan_t );

  `AXI_TYPEDEF_AW_CHAN_T(int_aw_t, addr_t, int_id_t, user_t);
  `AXI_TYPEDEF_W_CHAN_T(w_t, data_t, strb_t, user_t);
  `AXI_TYPEDEF_B_CHAN_T(int_b_t, int_id_t, user_t);
  `AXI_TYPEDEF_AR_CHAN_T(int_ar_t, addr_t, int_id_t, user_t);
  `AXI_TYPEDEF_R_CHAN_T(int_r_t, data_t, int_id_t, user_t);
  `AXI_TYPEDEF_REQ_T(slv_req_t, int_aw_t, w_t, int_ar_t);
  `AXI_TYPEDEF_RESP_T(slv_resp_t, int_b_t, int_r_t );

  mst_req_t   master_req;
  mst_resp_t  master_rsp;

  slv_req_t   slave_req;
  slv_resp_t  slave_rsp;

  `AXI_ASSIGN (master,           master_dv)
  `AXI_ASSIGN_TO_REQ(master_req, master)
  `AXI_ASSIGN_FROM_RESP(master,  master_rsp)

 // `AXI_ASSIGN (slave_dv,         slave)
  //`AXI_ASSIGN_FROM_REQ(slave,    slave_req)
  //`AXI_ASSIGN_TO_RESP(slave_rsp, slave)

  `REG_BUS_TYPEDEF_ALL(cfg,logic [31:0],logic [31:0], logic [7:0]);

  cfg_req_t cfg_req;
  cfg_rsp_t cfg_rsp;

  `REG_BUS_ASSIGN_TO_REQ(cfg_req, reg_bus)
  `REG_BUS_ASSIGN_FROM_RSP(reg_bus, cfg_rsp)
  //-----------------------------------
  // Clock generator
  //-----------------------------------
  clk_rst_gen #(
      .ClkPeriod    ( CyclTime ),
      .RstClkCycles ( 32'd5    )
  ) i_clk_gen (
      .clk_o        ( clk      ),
      .rst_no       ( rst_n    )
  );

  //-----------------------------------
  // AXI Simulation Memory
  //-----------------------------------
   axi_sim_mem #(
    .AddrWidth         ( TbAxiAddrWidth  ),
    .DataWidth         ( TbAxiDataWidth  ),
    .IdWidth           ( TbAxiIntIdWidth    ),
    .UserWidth         ( TbAxiUserWidth  ),
    .axi_req_t         ( slv_req_t     ),
    .axi_rsp_t         ( slv_resp_t    ),
    .WarnUninitialized ( 1'b0                   ),
    .ClearErrOnAccess  ( 1'b1                   ),
    .ApplDelay         ( ApplTime               ),
    .AcqDelay          ( TestTime               ),
    .UninitializedData ( "zeros"                )
  ) i_tx_axi_sim_mem (
    .clk_i              ( clk           ),
    .rst_ni             ( rst_n         ),
    .axi_req_i          ( slave_req     ),
    .axi_rsp_o          ( slave_rsp     ),
    .mon_r_last_o       ( /* NOT CONNECTED */ ),
    .mon_r_beat_count_o ( /* NOT CONNECTED */ ),
    .mon_r_user_o       ( /* NOT CONNECTED */ ),
    .mon_r_id_o         ( /* NOT CONNECTED */ ),
    .mon_r_data_o       ( /* NOT CONNECTED */ ),
    .mon_r_addr_o       ( /* NOT CONNECTED */ ),
    .mon_r_valid_o      ( /* NOT CONNECTED */ ),
    .mon_w_last_o       ( /* NOT CONNECTED */ ),
    .mon_w_beat_count_o ( /* NOT CONNECTED */ ),
    .mon_w_user_o       ( /* NOT CONNECTED */ ),
    .mon_w_id_o         ( /* NOT CONNECTED */ ),
    .mon_w_data_o       ( /* NOT CONNECTED */ ),
    .mon_w_addr_o       ( /* NOT CONNECTED */ ),
    .mon_w_valid_o      ( /* NOT CONNECTED */ )
  );

  //-----------------------------------
  // DUT
  //-----------------------------------
  axi_tmu_top
  // `ifndef TARGET_NETLIST_SIM
   #(
    .MaxUniqIds    (TbMaxUniqIds),
    .MaxTxnsPerId  (TbMaxTxnsPerId),
    .MaxWrTxns     (TbMaxWrTxns  ),
    .MaxRdTxns     (TbMaxRdTxns),
    .AxiIdWidth    (TbAxiIdWidth),
    .CounterWidth  (TbCounterWidth),
    .HsCntWidth    (TbHsCntWidth),
    .PrescalerDiv  (TbPrescalerDiv),
    .mgr_req_t        ( mst_req_t       ),
    .mgr_rsp_t        ( mst_resp_t      ),
    .sbr_req_t    ( slv_req_t       ),
    .sbr_rsp_t    ( slv_resp_t      ),
    .cfg_req_t    ( cfg_req_t       ),
    .cfg_rsp_t    ( cfg_rsp_t       )
  )
  //`endif
  //monitor_wrap
    i_slv_guard_top (
    .clk_i       (   clk          ),
    .rst_ni      (   rst_n        ),
    .mgr_req_i       (   master_req   ),
    .mgr_rsp_o       (   master_rsp   ),
    .sbr_req_o       (   slave_req    ), //
    .sbr_rsp_i       (   slave_rsp    ),
    .cfg_req_i   (   cfg_req      ),
    .cfg_rsp_o   (   cfg_rsp      ),
    .fault_o       (   irq          ),
    .rst_req_o   (   rst_stat     ),
    .reset_clear_i  (   1'b0         )
  );

  //-----------------------------------
  // TB
  //-----------------------------------
  initial begin : proc_axi_master
    automatic axi_file_master_t axi_file_master = new(master_dv);
    axi_file_master.reset();
    axi_file_master.load_files($sformatf("/scratch2/chaoliang/axi_monitor/test/stimuli/rd.txt"), $sformatf("/scratch2/chaoliang/axi_monitor/test/stimuli/32_wr.txt"));

    @(posedge rst_n);
    @(posedge clk);

    $readmemh("/scratch2/chaoliang/axi_monitor/test/stimuli/read.vmem", i_tx_axi_sim_mem.mem);
    repeat (5) @(posedge clk);
    axi_file_master.run();
  end

  // configure slv units
  initial begin
    // register bus
    automatic reg_drv_t reg_drv = new(reg_bus);
    reg_drv.reset_master();
    @(posedge rst_n);
    @(posedge clk);

    // slave unit enable 1 / disable 0
    reg_drv.send_write(32'h0000_0000, 32'h0000_0100, 4'hf, reg_error);

    // budget from aw_valid to aw_ready
    reg_drv.send_write(32'h0000_0004, 32'h0000_0001, 4'hf, reg_error);
    // time budget for unit length on w channel
    reg_drv.send_write(32'h0000_0008, 32'h0000_0001, 4'hf, reg_error);
    // budget from w_valid to w_ready
    reg_drv.send_write(32'h0000_000c, 32'h0000_0001, 4'hf, reg_error);
    // budget from w_last to b_valid
    reg_drv.send_write(32'h0000_0010, 32'h0000_0001, 4'hf, reg_error);
    // budget from b_valid to b_ready
    reg_drv.send_write(32'h0000_0014, 32'h0000_0001, 4'hf, reg_error);

    // budget from ar_valid to ar_ready
    reg_drv.send_write(32'h0000_0018, 32'h0000_0001, 4'hf, reg_error);
    // time budget for unit length on r channel
    reg_drv.send_write(32'h0000_001c, 32'h0000_0001, 4'hf, reg_error);
    // budget from rvld to rrdy
    reg_drv.send_write(32'h0000_0020, 32'h0000_0001, 4'hf, reg_error);

    repeat (1000) @(posedge clk);
    $stop();
  end
endmodule
