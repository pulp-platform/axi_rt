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
  parameter type         apb_req_t          = logic,
  parameter type         apb_resp_t         = logic,
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

  // APB configuration interface
  input  apb_req_t  apb_req_i,
  output apb_resp_t apb_rsp_o,
  input  reg_id_t   reg_id_i
);

  // helper types
  localparam type period_t       = logic    [PeriodWidth-1   :0];
  localparam type budget_t       = logic    [BudgetWidth-1   :0];
  localparam type period_array_t = period_t [NumAddrRegions-1:0];
  localparam type budget_array_t = budget_t [NumAddrRegions-1:0];

  // register signals (PeakRDL hardware interface)
  axi_rt_regs_pkg::axi_rt_regs__in_t  hwif_in;
  axi_rt_regs_pkg::axi_rt_regs__out_t hwif_out;

  // guarded APB bus between the access guard and the register block
  apb_req_t  guard_apb_req;
  apb_resp_t guard_apb_rsp;

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
    .SubAddrWidth ( axi_rt_regs_pkg::AXI_RT_REGS_MIN_ADDR_WIDTH + 32'd1 ),
    .RegIdWidth   ( RegIdWidth                                          ),
    .DataWidth    ( 32'd32                                              ),
    .apb_req_t    ( apb_req_t                                           ),
    .apb_resp_t   ( apb_resp_t                                          )
  ) i_axi_rt_regbus_guard (
    .clk_i,
    .rst_ni,
    .id_i    ( reg_id_i      ),
    .req_i   ( apb_req_i     ),
    .rsp_o   ( apb_rsp_o     ),
    .req_o   ( guard_apb_req ),
    .rsp_i   ( guard_apb_rsp )
  );

  axi_rt_regs i_axi_rt_regs (
    .clk           ( clk_i  ),
    .arst_n        ( rst_ni ),
    // APB slave (flat) driven from the guarded request
    .s_apb_psel    ( guard_apb_req.psel    ),
    .s_apb_penable ( guard_apb_req.penable ),
    .s_apb_pwrite  ( guard_apb_req.pwrite  ),
    .s_apb_pprot   ( guard_apb_req.pprot   ),
    .s_apb_paddr   ( guard_apb_req.paddr[axi_rt_regs_pkg::AXI_RT_REGS_MIN_ADDR_WIDTH-1:0] ),
    .s_apb_pwdata  ( guard_apb_req.pwdata  ),
    .s_apb_pstrb   ( guard_apb_req.pstrb   ),
    .s_apb_pready  ( guard_apb_rsp.pready  ),
    .s_apb_prdata  ( guard_apb_rsp.prdata  ),
    .s_apb_pslverr ( guard_apb_rsp.pslverr ),
    .hwif_in       ( hwif_in  ),
    .hwif_out      ( hwif_out )
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
      .rt_enable_i      ( hwif_out.rt_enable   [i].enable.value ),
      .rt_bypassed_o    ( hwif_in.rt_bypassed  [i].bypassed.next ),
      .len_limit_i      ( hwif_out.len_limit   [i].len.value    ),
      .num_w_pending_o  ( /* NOT CONNECTED */    ),
      .num_aw_pending_o ( /* NOT CONNECTED */    ),
      .rt_rule_i        ( addr_map_i             ),
      .w_decode_error_o (  /* NOT CONNECTED */   ),
      .r_decode_error_o (  /* NOT CONNECTED */   ),
      .imtu_enable_i    ( hwif_out.imtu_enable [i].enable.value ),
      .imtu_abort_i     ( hwif_out.imtu_abort  [i].abort.value  ),
      .r_budget_i       ( r_budget               ),
      .r_budget_left_o  ( r_budget_left          ),
      .r_period_i       ( r_period               ),
      .r_period_left_o  ( r_period_left          ),
      .w_budget_i       ( w_budget               ),
      .w_budget_left_o  ( w_budget_left          ),
      .w_period_i       ( w_period               ),
      .w_period_left_o  ( w_period_left          ),
      .isolate_o        ( hwif_in.isolate      [i].isolate.next  ),
      .isolated_o       ( hwif_in.isolated     [i].isolated.next )
    );

    // assemble budget/period structs and connect live status back to registers
    for (genvar r = 0; r < NumAddrRegions; r++) begin : gen_region_conn
      localparam int unsigned RegIdx = i * NumAddrRegions + r;

      assign r_budget[r] = hwif_out.read_budget  [RegIdx].budget.value[BudgetWidth-1:0];
      assign r_period[r] = hwif_out.read_period  [RegIdx].period.value[PeriodWidth-1:0];
      assign w_budget[r] = hwif_out.write_budget [RegIdx].budget.value[BudgetWidth-1:0];
      assign w_period[r] = hwif_out.write_period [RegIdx].period.value[PeriodWidth-1:0];

      assign hwif_in.read_budget_left  [RegIdx].budget.next = r_budget_left[r];
      assign hwif_in.read_period_left  [RegIdx].period.next = r_period_left[r];
      assign hwif_in.write_budget_left [RegIdx].budget.next = w_budget_left[r];
      assign hwif_in.write_period_left [RegIdx].period.next = w_period_left[r];
    end

    // connect address map
    always_comb begin : proc_assemble_rule
      for (int unsigned r = 0; r < NumAddrRegions; r++) begin
        addr_map_i[r] = rt_rule_t'{
          idx:        unsigned'(r),
          start_addr: { hwif_out.start_addr_sub_high[i * NumAddrRegions + r].addr.value,
                        hwif_out.start_addr_sub_low [i * NumAddrRegions + r].addr.value },
          end_addr:   { hwif_out.end_addr_sub_high  [i * NumAddrRegions + r].addr.value,
                        hwif_out.end_addr_sub_low   [i * NumAddrRegions + r].addr.value },
          default:    '0
        };
      end
    end

    // end generate
  end

  // assign the parameters to the registers
  assign hwif_in.num_managers.num_managers.next         = NumManagers;
  assign hwif_in.addr_width.addr_width.next             = AddrWidth;
  assign hwif_in.data_width.data_width.next             = DataWidth;
  assign hwif_in.id_width.id_width.next                 = IdWidth;
  assign hwif_in.user_width.user_width.next             = UserWidth;
  assign hwif_in.num_pending.num_pending.next           = NumPending;
  assign hwif_in.w_buffer_depth.w_buffer_depth.next     = WBufferDepth;
  assign hwif_in.num_addr_regions.num_addr_regions.next = NumAddrRegions;
  assign hwif_in.period_width.period_width.next         = PeriodWidth;
  assign hwif_in.budget_width.budget_width.next         = BudgetWidth;

endmodule
