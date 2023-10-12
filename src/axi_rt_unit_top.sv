// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Thomas Benz <tbenz@ethz.ch>

`include "common_cells/registers.svh"

/// Real-time unit: fragments and throttles transactions. Top-lvl unit includes the registers
module axi_rt_unit_top #(
  parameter int unsigned NumManagers        = 32'd0,
  parameter int unsigned AddrWidth          = 32'd0,
  parameter int unsigned DataWidth          = 32'd0,
  parameter int unsigned IdWidth            = 32'd0,
  parameter int unsigned UserWidth          = 32'd0,
  parameter int unsigned NumPending         = 32'd0,
  parameter int unsigned WBufferDepth       = 32'd0,
  parameter int unsigned NumAddrRegions     = 32'd0,
  parameter int unsigned PeriodWidth        = 32'd0,
  parameter int unsigned BudgetWidth        = 32'd0,
  parameter int unsigned RegIdWidth         = 32'd0,
  parameter bit          CutSplitterPaths   =  1'b0,
  parameter bit          DisableSplitChecks =  1'b0,
  parameter bit          CutDecErrors       =  1'b0,
  parameter type         aw_chan_t          = logic,
  parameter type         w_chan_t           = logic,
  parameter type         b_chan_t           = logic,
  parameter type         ar_chan_t          = logic,
  parameter type         r_chan_t           = logic,
  parameter type         axi_req_t          = logic,
  parameter type         axi_resp_t         = logic,
  parameter type         req_req_t          = logic,
  parameter type         req_rsp_t          = logic,
  // dependent parameters
  parameter type         addr_t             = logic [AddrWidth-1:0],
  parameter type         reg_id_t           = logic [RegIdWidth-1:0]
)(
  input logic clk_i,
  input logic rst_ni,

  // Input / Subordinate Ports
  input  axi_req_t  [NumManagers-1:0] slv_req_i,
  output axi_resp_t [NumManagers-1:0] slv_resp_o,

  // Output / Manager Ports
  output axi_req_t  [NumManagers-1:0] mst_req_o,
  input  axi_resp_t [NumManagers-1:0] mst_resp_i,

  // Register interface
  input  req_req_t reg_req_i,
  output req_rsp_t reg_rsp_o,
  input  reg_id_t  reg_id_i
);

  // helper types
  localparam type period_t       = logic    [PeriodWidth-1   :0];
  localparam type budget_t       = logic    [BudgetWidth-1   :0];
  localparam type period_array_t = period_t [NumAddrRegions-1:0];
  localparam type budget_array_t = budget_t [NumAddrRegions-1:0];

  // register signals
  axi_rt_reg_pkg::axi_rt_reg2hw_t reg2hw;
  axi_rt_reg_pkg::axi_rt_hw2reg_t hw2reg;

  // guarded bus
  req_req_t guard_reg_req;
  req_rsp_t guard_reg_rsp;

  /// rule type
  typedef struct packed {
    logic [7:0] idx;
    addr_t      start_addr;
    addr_t      end_addr;
  } rt_rule_t;


  //-----------------------------------
  // Register
  //-----------------------------------
  axi_rt_regbus_guard #(
    .SubAddrWidth ( axi_rt_reg_pkg::BlockAw + 32'd1 ),
    .RegIdWidth   ( RegIdWidth                      ),
    .DataWidth    ( 32'd32                          ),
    .reg_req_t    ( req_req_t                       ),
    .reg_rsp_t    ( req_rsp_t                       )
  ) i_axi_rt_regbus_guard (
    .clk_i,
    .rst_ni,
    .id_i    ( reg_id_i      ),
    .req_i   ( reg_req_i     ),
    .rsp_o   ( reg_rsp_o     ),
    .req_o   ( guard_reg_req ),
    .rsp_i   ( guard_reg_rsp )
  );

  axi_rt_reg_top #(
    .reg_req_t ( req_req_t ),
    .reg_rsp_t ( req_rsp_t )
  ) i_axi_rt_reg_top (
    .clk_i,
    .rst_ni,
    .reg_req_i  ( guard_reg_req ),
    .reg_rsp_o  ( guard_reg_rsp ),
    .reg2hw     ( reg2hw        ),
    .hw2reg     ( hw2reg        ),
    .devmode_i  ( 1'b1          )
  );


  //-----------------------------------
  // RT units
  //-----------------------------------
  for (genvar i = 0; i < NumManagers; i++) begin : gen_rt_units

    // assemble the rules
    rt_rule_t [NumAddrRegions-1:0] addr_map_i;

    // budget and period arrays
    budget_array_t r_budget;
    budget_array_t r_budget_left;
    period_array_t r_period;
    period_array_t r_period_left;
    budget_array_t w_budget;
    budget_array_t w_budget_left;
    period_array_t w_period;
    period_array_t w_period_left;

    // rt unit core
    axi_rt_unit #(
      .AddrWidth          ( AddrWidth          ),
      .DataWidth          ( DataWidth          ),
      .IdWidth            ( IdWidth            ),
      .UserWidth          ( UserWidth          ),
      .NumPending         ( NumPending         ),
      .WBufferDepth       ( WBufferDepth       ),
      .NumAddrRegions     ( NumAddrRegions     ),
      .NumRules           ( NumAddrRegions     ),
      .BudgetWidth        ( BudgetWidth        ),
      .PeriodWidth        ( PeriodWidth        ),
      .CutDecErrors       ( CutDecErrors       ),
      .CutSplitterPaths   ( CutSplitterPaths   ),
      .DisableSplitChecks ( DisableSplitChecks ),
      .rt_rule_t          ( rt_rule_t          ),
      .addr_t             ( addr_t             ),
      .aw_chan_t          ( aw_chan_t          ),
      .ar_chan_t          ( ar_chan_t          ),
      .w_chan_t           ( w_chan_t           ),
      .b_chan_t           ( b_chan_t           ),
      .r_chan_t           ( r_chan_t           ),
      .axi_req_t          ( axi_req_t          ),
      .axi_resp_t         ( axi_resp_t         )
    ) i_axi_rt_unit (
      .clk_i,
      .rst_ni,
      .slv_req_i        ( slv_req_i          [i] ),
      .slv_resp_o       ( slv_resp_o         [i] ),
      .mst_req_o        ( mst_req_o          [i] ),
      .mst_resp_i       ( mst_resp_i         [i] ),
      .rt_enable_i      ( reg2hw.rt_enable   [i] ),
      .rt_bypassed_o    ( hw2reg.rt_bypassed [i] ),
      .len_limit_i      ( reg2hw.len_limit   [i] ),
      .num_w_pending_o  ( /* NOT CONNECTED */    ),
      .num_aw_pending_o ( /* NOT CONNECTED */    ),
      .rt_rule_i        ( addr_map_i             ),
      .w_decode_error_o (  /* NOT CONNECTED */   ),
      .r_decode_error_o (  /* NOT CONNECTED */   ),
      .imtu_enable_i    ( reg2hw.imtu_enable [i] ),
      .imtu_abort_i     ( reg2hw.imtu_abort  [i] ),
      .r_budget_i       ( r_budget               ),
      .r_budget_left_o  ( r_budget_left          ),
      .r_period_i       ( r_period               ),
      .r_period_left_o  ( r_period_left          ),
      .w_budget_i       ( w_budget               ),
      .w_budget_left_o  ( w_budget_left          ),
      .w_period_i       ( w_period               ),
      .w_period_left_o  ( w_period_left          ),
      .isolate_o        ( hw2reg.isolate     [i] ),
      .isolated_o       ( hw2reg.isolated    [i] )
    );

    // assemble budget/period structs
    assign r_budget = reg2hw.read_budget  [i * NumAddrRegions +: NumAddrRegions];
    assign r_period = reg2hw.read_period  [i * NumAddrRegions +: NumAddrRegions];
    assign w_budget = reg2hw.write_budget [i * NumAddrRegions +: NumAddrRegions];
    assign w_period = reg2hw.write_period [i * NumAddrRegions +: NumAddrRegions];

    // read budget/period left
    always_comb begin : proc_assemble_hw2reg
      hw2reg.read_budget_left  [i * NumAddrRegions +: NumAddrRegions] = r_budget_left;
      hw2reg.read_period_left  [i * NumAddrRegions +: NumAddrRegions] = r_period_left;
      hw2reg.write_budget_left [i * NumAddrRegions +: NumAddrRegions] = w_budget_left;
      hw2reg.write_period_left [i * NumAddrRegions +: NumAddrRegions] = w_period_left;
    end

    // connect address map
    always_comb begin : proc_assemble_rule
      for (int unsigned r = 0; r < NumAddrRegions; r++) begin
        addr_map_i[r] = rt_rule_t'{
          idx:        unsigned'(r),
          start_addr: { reg2hw.start_addr_sub_high[i * NumAddrRegions + r],
                        reg2hw.start_addr_sub_low [i * NumAddrRegions + r] },
          end_addr:   { reg2hw.end_addr_sub_high  [i * NumAddrRegions + r],
                        reg2hw.end_addr_sub_low   [i * NumAddrRegions + r] },
          default:    '0
        };
      end
    end

    // end generate
  end

  // assign the parameters to the registers
  assign hw2reg.num_managers     = NumManagers;
  assign hw2reg.addr_width       = AddrWidth;
  assign hw2reg.data_width       = DataWidth;
  assign hw2reg.id_width         = IdWidth;
  assign hw2reg.user_width       = UserWidth;
  assign hw2reg.num_pending      = NumPending;
  assign hw2reg.w_buffer_depth   = WBufferDepth;
  assign hw2reg.num_addr_regions = NumAddrRegions;
  assign hw2reg.period_width     = PeriodWidth;
  assign hw2reg.budget_width     = BudgetWidth;

endmodule
