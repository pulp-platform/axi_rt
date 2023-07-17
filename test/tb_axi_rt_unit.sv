// Copyright (c) 2019 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Authors:
// - Thomas Benz <tbenz@ethz.ch>
// - Noah Huetter <huettern@ethz.ch>

// vsim -t 1ns -voptargs=+acc tb_axi_rt_unit; log -r /*;

`include "axi/typedef.svh"
`include "axi/assign.svh"
`include "axi-rt/assign.svh"

/// Testbench for the AXI RT unit
/// Codename `Mr Poopybutthole`
module tb_axi_rt_unit #(
  /// Number of masters
  parameter int unsigned TbNumMasters    = 32'd1,
  /// Number of slaves
  parameter int unsigned TbNumSlaves     = 32'd1,
  /// Number of outstanding Transactions
  parameter int unsigned TbNumPending    = 32'd4,
  /// Depth of the Buffer
  parameter int unsigned TbWBufferDepth  = 32'd16,
  /// Testbench timing
  parameter time CyclTime                = 10000ps,
  parameter time ApplTime                = 100ps,
  parameter time TestTime                = 500ps,
  // AXI configuration
  parameter int unsigned TbAxiIdWidth    = 32'd2,
  parameter int unsigned TbAxiAddrWidth  = 32'd32,
  parameter int unsigned TbAxiDataWidth  = 32'd32,
  parameter int unsigned TbAxiUserWidth  = 32'd1
);

  /// Sim print config, how many transactions
  localparam int unsigned TbPrintTnx = 32'd100;

  // Calc slave id
  localparam int unsigned TbAxiSlvIdWidth = (TbNumMasters == 32'd1 & TbNumSlaves == 32'd1) ?
                                             TbAxiIdWidth :
                                             TbAxiIdWidth + cf_math_pkg::idx_width(TbNumMasters);

  // RT unit parameters
  localparam int unsigned TbPeriodWidth = 32'd32;
  localparam int unsigned TbBudgetWidth = 32'd32;
  localparam int unsigned TbIdxWWidth   = cf_math_pkg::idx_width(TbWBufferDepth);
  localparam int unsigned TbIdxAwWidth  = cf_math_pkg::idx_width(TbNumPending);
  localparam type         idx_w_t       = logic [TbIdxWWidth-1:0];
  localparam type         idx_aw_t      = logic [TbIdxAwWidth-1:0];
  localparam type         period_t      = logic [TbPeriodWidth-1:0];
  localparam type         budget_t      = logic [TbBudgetWidth-1:0];

  localparam type         word_t        = logic [31:0];

  // typedef
  typedef logic [TbAxiIdWidth-1    :0] id_t;
  typedef logic [TbAxiSlvIdWidth-1 :0] slv_id_t;
  typedef logic [TbAxiAddrWidth-1  :0] addr_t;
  typedef logic [TbAxiDataWidth-1  :0] data_t;
  typedef logic [TbAxiDataWidth/8-1:0] strb_t;
  typedef logic [TbAxiUserWidth-1  :0] user_t;

  `AXI_TYPEDEF_ALL(axi,     addr_t, id_t,     data_t, strb_t, user_t)
  `AXI_TYPEDEF_ALL(axi_slv, addr_t, slv_id_t, data_t, strb_t, user_t)

    /// rule type
  typedef struct packed {
    logic [7:0] idx;
    addr_t      start_addr;
    addr_t      end_addr;
  } rt_rule_t;

  /// Number of Address Rules
  localparam int unsigned TbNumAddrRegions = 32'd3;
  localparam int unsigned TbNumRules       = TbNumSlaves;

  typedef axi_test::axi_file_master#(
      .AW                   ( TbAxiAddrWidth ),
      .DW                   ( TbAxiDataWidth ),
      .IW                   ( TbAxiIdWidth   ),
      .UW                   ( TbAxiUserWidth ),
      .TA                   ( ApplTime       ),
      .TT                   ( TestTime       )
  ) axi_file_master_t;

  typedef axi_test::axi_driver #(
    .AW( TbAxiAddrWidth ),
    .DW( TbAxiDataWidth ),
    .IW( TbAxiIdWidth   ),
    .UW( TbAxiUserWidth ),
    .TA( ApplTime       ),
    .TT( TestTime       )
  ) drv_t;

  /// Random AXI slave type
  typedef axi_test::axi_rand_slave#(
      .AW                   ( TbAxiAddrWidth  ),
      .DW                   ( TbAxiDataWidth  ),
      .IW                   ( TbAxiSlvIdWidth ),
      .UW                   ( TbAxiUserWidth  ),
      .TA                   ( ApplTime        ),
      .TT                   ( TestTime        ),
      .AX_MIN_WAIT_CYCLES   ( 32'd0           ),
      .AX_MAX_WAIT_CYCLES   ( 32'd0           ),
      .R_MIN_WAIT_CYCLES    ( 32'd0           ),
      .R_MAX_WAIT_CYCLES    ( 32'd0           ),
      .RESP_MIN_WAIT_CYCLES ( 32'd0           ),
      .RESP_MAX_WAIT_CYCLES ( 32'd0           ),
      .MAPPED               ( 1'b0            )
  ) axi_rand_slave_t;


  // -------------
  // DUT signals
  // -------------
  logic clk;
  logic rst_n;


  logic  [TbNumMasters-1:0] end_of_sim;
  logic                     done;
  word_t [TbNumMasters-1:0] total_num_reads;
  word_t [TbNumMasters-1:0] total_num_writes;
  word_t [TbNumMasters-1:0] num_reads;
  word_t [TbNumMasters-1:0] num_writes;

  logic       [TbNumMasters-1:0] master_aw_valids;
  logic       [TbNumMasters-1:0] master_aw_readys;
  logic       [TbNumMasters-1:0] master_ar_valids;
  logic       [TbNumMasters-1:0] master_ar_readys;

  // RT config and status signals
  logic                                        rt_enable = '0;
  logic                     [TbNumMasters-1:0] rt_bypassed;
  axi_pkg::len_t                               len_limit = '0;
  idx_w_t                   [TbNumMasters-1:0] num_w_pending;
  idx_aw_t                  [TbNumMasters-1:0] num_aw_pending;
  logic                     [TbNumMasters-1:0] w_decode_error;
  logic                     [TbNumMasters-1:0] r_decode_error;
  logic                     [TbNumMasters-1:0] imtu_enable = '0;
  logic                     [TbNumMasters-1:0] imtu_abort = '0;
  budget_t [TbNumMasters-1:0][TbNumSlaves-1:0] w_budget = '0;
  budget_t [TbNumMasters-1:0][TbNumSlaves-1:0] w_budget_left;
  period_t [TbNumMasters-1:0][TbNumSlaves-1:0] w_period = '0;
  period_t [TbNumMasters-1:0][TbNumSlaves-1:0] w_period_left;
  budget_t [TbNumMasters-1:0][TbNumSlaves-1:0] r_budget = '0;
  budget_t [TbNumMasters-1:0][TbNumSlaves-1:0] r_budget_left;
  period_t [TbNumMasters-1:0][TbNumSlaves-1:0] r_period = '0;
  period_t [TbNumMasters-1:0][TbNumSlaves-1:0] r_period_left;
  logic                     [TbNumMasters-1:0] isolate;
  logic                     [TbNumMasters-1:0] isolated;

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth ),
    .AXI_ID_WIDTH   ( TbAxiIdWidth   ),
    .AXI_USER_WIDTH ( TbAxiUserWidth )
  ) master [TbNumMasters-1:0] ();

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth  ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth  ),
    .AXI_ID_WIDTH   ( TbAxiSlvIdWidth ),
    .AXI_USER_WIDTH ( TbAxiUserWidth  )
  ) slave [TbNumSlaves-1:0] ();

  AXI_BUS_DV #(
      .AXI_ADDR_WIDTH ( TbAxiAddrWidth ),
      .AXI_DATA_WIDTH ( TbAxiDataWidth ),
      .AXI_ID_WIDTH   ( TbAxiIdWidth   ),
      .AXI_USER_WIDTH ( TbAxiUserWidth )
  ) master_dv [TbNumMasters-1:0] (clk);

  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth  ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth  ),
    .AXI_ID_WIDTH   ( TbAxiSlvIdWidth ),
    .AXI_USER_WIDTH ( TbAxiUserWidth  )
  ) slave_dv [TbNumSlaves-1:0] (clk);


  axi_req_t      [TbNumMasters-1:0] master_req;
  axi_resp_t     [TbNumMasters-1:0] master_rsp;
  axi_req_t      [TbNumMasters-1:0] rt_req;
  axi_resp_t     [TbNumMasters-1:0] rt_rsp;

  axi_slv_req_t  [TbNumSlaves-1:0]  slave_req;
  axi_slv_resp_t [TbNumSlaves-1:0]  slave_rsp;

  for (genvar i = 0; i < TbNumMasters; i++) begin : gen_conn_dv_masters
    `AXI_ASSIGN (master[i],           master_dv[i])
    `AXI_ASSIGN_TO_REQ(master_req[i], master[i])
    `AXI_ASSIGN_FROM_RESP(master[i],  master_rsp[i])
  end

  for (genvar i = 0; i < TbNumSlaves; i++) begin : gen_conn_dv_slaves
    `AXI_ASSIGN (slave_dv[i],         slave[i])
    `AXI_ASSIGN_FROM_REQ(slave[i],    slave_req[i])
    `AXI_ASSIGN_TO_RESP(slave_rsp[i], slave[i])
  end


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

  for (genvar i = 0; i < TbNumMasters; i++) begin : gen_coneect_hs_signals
    assign master_ar_valids [i] = master_req[i].ar_valid;
    assign master_ar_readys [i] = master_rsp[i].ar_ready;
    assign master_aw_valids [i] = master_req[i].aw_valid;
    assign master_aw_readys [i] = master_rsp[i].aw_ready;
  end


  stream_watchdog #(
    .NumCycles ( 1000 )
  ) i_stream_watchdog_aw (
    .clk_i   ( clk                                    ),
    .rst_ni  ( rst_n                                  ),
    .valid_i ( |(master_aw_valids & master_aw_readys) ),
    .ready_i ( 1'b1                                   )
  );

  stream_watchdog #(
    .NumCycles ( 1000 )
  ) i_stream_watchdog_ar (
    .clk_i   ( clk                                    ),
    .rst_ni  ( rst_n                                  ),
    .valid_i ( |(master_ar_valids & master_ar_readys) ),
    .ready_i ( 1'b1                                   )
  );



  // add highlighters
  for (genvar i = 0; i < TbNumMasters; i++) begin : gen_highlighters
    `AXI_HIGHLIGHT(rt_in,  axi_aw_chan_t, axi_w_chan_t, axi_b_chan_t, axi_ar_chan_t, axi_r_chan_t, master_req[i], master_rsp[i])
    `AXI_HIGHLIGHT(rt_out, axi_aw_chan_t, axi_w_chan_t, axi_b_chan_t, axi_ar_chan_t, axi_r_chan_t, rt_req[i],     rt_rsp[i])
  end

  localparam axi_pkg::xbar_cfg_t xbar_cfg = '{
    NoSlvPorts:         TbNumMasters,
    NoMstPorts:         TbNumSlaves,
    MaxMstTrans:        8,
    MaxSlvTrans:        8,
    FallThrough:        1'b0,
    LatencyMode:        axi_pkg::NO_LATENCY,
    PipelineStages:     0,
    AxiIdWidthSlvPorts: TbAxiIdWidth,
    AxiIdUsedSlvPorts:  TbAxiIdWidth,
    UniqueIds:          0,
    AxiAddrWidth:       TbAxiAddrWidth,
    AxiDataWidth:       TbAxiDataWidth,
    NoAddrRules:        TbNumSlaves
  };

  // Each slave has its own address range:
  localparam rt_rule_t [xbar_cfg.NoAddrRules-1:0] AddrMap = addr_map_gen();

  function automatic rt_rule_t [xbar_cfg.NoAddrRules-1:0] addr_map_gen ();
    for (int unsigned i = 0; i < xbar_cfg.NoAddrRules; i++) begin
      addr_map_gen[i] = rt_rule_t'{
        idx:        unsigned'(i),
        start_addr:  i    * 32'h0001_0000,
        end_addr:   (i+1) * 32'h0001_0000,
        default:    '0
      };
    end
  endfunction


  //-----------------------------------
  // DUT
  //-----------------------------------
  for (genvar i = 0; i < TbNumMasters; i++) begin : gen_rt_units

    axi_rt_unit #(
      .AddrWidth      ( TbAxiAddrWidth   ),
      .DataWidth      ( TbAxiDataWidth   ),
      .IdWidth        ( TbAxiIdWidth     ),
      .UserWidth      ( TbAxiUserWidth   ),
      .NumPending     ( TbNumPending     ),
      .WBufferDepth   ( TbWBufferDepth   ),
      .NumAddrRegions ( TbNumSlaves      ),
      .NumRules       ( TbNumSlaves      ),
      .BudgetWidth    ( TbBudgetWidth    ),
      .PeriodWidth    ( TbPeriodWidth    ),
      .rt_rule_t      ( rt_rule_t        ),
      .addr_t         ( addr_t           ),
      .aw_chan_t      ( axi_aw_chan_t    ),
      .ar_chan_t      ( axi_ar_chan_t    ),
      .w_chan_t       ( axi_w_chan_t     ),
      .r_chan_t       ( axi_r_chan_t     ),
      .b_chan_t       ( axi_b_chan_t     ),
      .axi_req_t      ( axi_req_t        ),
      .axi_resp_t     ( axi_resp_t       )
    ) i_axi_rt_unit (
      .clk_i            ( clk                ),
      .rst_ni           ( rst_n              ),
      .slv_req_i        ( master_req     [i] ),
      .slv_resp_o       ( master_rsp     [i] ),
      .mst_req_o        ( rt_req         [i] ),
      .mst_resp_i       ( rt_rsp         [i] ),
      .rt_enable_i      ( rt_enable          ),
      .rt_bypassed_o    ( rt_bypassed    [i] ),
      .len_limit_i      ( len_limit          ),
      .num_w_pending_o  ( num_w_pending  [i] ),
      .num_aw_pending_o ( num_aw_pending [i] ),
      .rt_rule_i        ( AddrMap            ),
      .w_decode_error_o ( w_decode_error [i] ),
      .r_decode_error_o ( r_decode_error [i] ),
      .imtu_enable_i    ( imtu_enable    [i] ),
      .imtu_abort_i     ( imtu_abort     [i] ),
      .r_budget_i       ( w_budget       [i] ),
      .r_budget_left_o  ( w_budget_left  [i] ),
      .r_period_i       ( w_period       [i] ),
      .r_period_left_o  ( w_period_left  [i] ),
      .w_budget_i       ( r_budget       [i] ),
      .w_budget_left_o  ( r_budget_left  [i] ),
      .w_period_i       ( r_period       [i] ),
      .w_period_left_o  ( r_period_left  [i] ),
      .isolate_o        ( isolate        [i] ),
      .isolated_o       ( isolated       [i] )
    );
  end


  // configuration tasks
  task rt_unit_enable (
    input axi_pkg::len_t len_limit_i
  );
    rt_enable   = 1'b1;
    len_limit   = len_limit_i;
    imtu_enable = '1;
    imtu_abort  = '0;
  endtask

  task rt_unit_configure (
    input period_t w_period_i,
    input period_t r_period_i,
    input period_t w_budget_i,
    input period_t r_budget_i
  );

    for (int i = 0; i < TbNumMasters; i++) begin
      for (int j = 0; j < TbNumSlaves; j++) begin
        w_budget[i][j] = w_budget_i;
        w_period[i][j] = w_period_i;
        r_budget[i][j] = r_budget_i;
        r_period[i][j] = r_period_i;
      end
    end
  endtask


  // include an X-bar
  if (TbNumMasters == 32'd1 & TbNumSlaves == 32'd1) begin : gen_bypass
    assign slave_req[0] = rt_req[0];
    assign rt_rsp   [0] = slave_rsp[0];

  // we need to instantiate a x-bar
  end else begin : gen_xbar

    // instantiate the X-bar
    axi_xbar #(
      .Cfg           ( xbar_cfg          ),
      .ATOPs         ( 1'b1              ),
      .Connectivity  ( '1                ),
      .slv_aw_chan_t ( axi_aw_chan_t     ),
      .mst_aw_chan_t ( axi_slv_aw_chan_t ),
      .w_chan_t      ( axi_w_chan_t      ),
      .slv_b_chan_t  ( axi_b_chan_t      ),
      .mst_b_chan_t  ( axi_slv_b_chan_t  ),
      .slv_ar_chan_t ( axi_ar_chan_t     ),
      .mst_ar_chan_t ( axi_slv_ar_chan_t ),
      .slv_r_chan_t  ( axi_r_chan_t      ),
      .mst_r_chan_t  ( axi_slv_r_chan_t  ),
      .slv_req_t     ( axi_req_t         ),
      .slv_resp_t    ( axi_resp_t        ),
      .mst_req_t     ( axi_slv_req_t     ),
      .mst_resp_t    ( axi_slv_resp_t    ),
      .rule_t        ( rt_rule_t         )
    ) i_axi_xbar (
      .clk_i                  ( clk       ),
      .rst_ni                 ( rst_n     ),
      .test_i                 ( 1'b0      ),
      .slv_ports_req_i        ( rt_req    ),
      .slv_ports_resp_o       ( rt_rsp    ),
      .mst_ports_req_o        ( slave_req ),
      .mst_ports_resp_i       ( slave_rsp ),
      .addr_map_i             ( AddrMap   ),
      .en_default_mst_port_i  ( '0        ),
      .default_mst_port_i     ( '0        )
    );
  end


  //-----------------------------------
  // TB
  //-----------------------------------

  for (genvar i = 0; i < TbNumMasters; i++) begin : gen_master_drivers
    initial begin : proc_axi_master
      automatic axi_file_master_t axi_file_master = new(master_dv[i]);
      axi_file_master.reset();
      axi_file_master.load_files($sformatf("test/stimuli/axi_rt_unit_%04h.reads.txt", i), $sformatf("test/stimuli/axi_rt_unit_%04h.writes.txt", i));
      total_num_reads [i] = axi_file_master.num_reads;
      total_num_writes[i] = axi_file_master.num_writes;
      num_writes      [i] = 1;
      num_reads       [i] = 1;
      end_of_sim [i] = 1'b0;
      // configure RT units
      @(posedge rst_n);
      @(posedge clk);
      rt_unit_configure(1000, 1000, 128*1024, 128*1024);
      rt_unit_enable(7);
      repeat (10) @(posedge clk);
      axi_file_master.run();
      end_of_sim [i] = 1'b1;
    end
  end

  for (genvar i = 0; i < TbNumSlaves; i++) begin : gen_slave_drivers
    initial begin : proc_axi_slave
      automatic axi_rand_slave_t axi_rand_slave = new(slave_dv[i]);
      axi_rand_slave.reset();
      @(posedge rst_n);
      axi_rand_slave.run();
    end
  end

  for (genvar i = 0; i < TbNumMasters; i++) begin : gen_print_progress
    initial begin : proc_sim_progress
      @(posedge rst_n);

      forever begin
        @(posedge clk);
        if (master[i].aw_valid & master[i].aw_ready) begin
          if (num_writes[i] % TbPrintTnx == 0) begin
            $display("%t> (%04h): Transmit AW %d of %d.", $time(), i, num_writes[i], total_num_writes[i]);
          end
          num_writes[i]++;
        end
        if (master[i].ar_valid & master[i].ar_ready) begin
          if (num_reads[i] % TbPrintTnx == 0) begin
            $display("%t> (%04h): Transmit AR %d of %d.", $time(), i, num_reads[i], total_num_reads[i]);
          end
          num_reads[i]++;
        end

        if (end_of_sim[i]) begin
          $display("All transactions completed for master %04h.", i);
          break;
        end
      end
    end
  end

  assign done = |end_of_sim;

  initial begin : proc_stop_sim
    @(posedge rst_n);
    @(posedge done);
    @(posedge clk)
    $info("All transaction sent!");
    repeat (100) @(posedge clk);
    $stop();
  end


  // default disable iff (!rst_n); aw_unstable :
  // assert property (@(posedge clk) (slave.aw_valid && !slave.aw_ready) |=> $stable(slave.aw_addr))
  // else $fatal(1, "AW is unstable.");
  // w_unstable :
  // assert property (@(posedge clk) (slave.w_valid && !slave.w_ready) |=> $stable(slave.w_data))
  // else $fatal(1, "W is unstable.");
  // b_unstable :
  // assert property (@(posedge clk) (master.b_valid && !master.b_ready) |=> $stable(master.b_resp))
  // else $fatal(1, "B is unstable.");
  // ar_unstable :
  // assert property (@(posedge clk) (slave.ar_valid && !slave.ar_ready) |=> $stable(slave.ar_addr))
  // else $fatal(1, "AR is unstable.");
  // r_unstable :
  // assert property (@(posedge clk) (master.r_valid && !master.r_ready) |=> $stable(master.r_data))
  // else $fatal(1, "R is unstable.");

endmodule
