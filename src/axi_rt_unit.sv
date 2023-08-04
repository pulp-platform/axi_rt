// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Thomas Benz <tbenz@ethz.ch>

`include "common_cells/registers.svh"

/// Real-time unit: fragments and throttles transactions
module axi_rt_unit #(
  parameter int unsigned AddrWidth        = 32'd0,
  parameter int unsigned DataWidth        = 32'd0,
  parameter int unsigned IdWidth          = 32'd0,
  parameter int unsigned UserWidth        = 32'd0,
  parameter int unsigned NumPending       = 32'd0,
  parameter int unsigned WBufferDepth     = 32'd0,
  parameter int unsigned NumAddrRegions   = 32'd0,
  parameter int unsigned NumRules         = 32'd0,
  parameter int unsigned PeriodWidth      = 32'd0,
  parameter int unsigned BudgetWidth      = 32'd0,
  parameter bit          CutSplitterPaths =  1'b0,
  parameter bit          CutDecErrors     =  1'b0,
  parameter type         rt_rule_t        = logic,
  parameter type         aw_chan_t        = logic,
  parameter type         w_chan_t         = logic,
  parameter type         b_chan_t         = logic,
  parameter type         ar_chan_t        = logic,
  parameter type         r_chan_t         = logic,
  parameter type         axi_req_t        = logic,
  parameter type         axi_resp_t       = logic,
  // dependent
  parameter int unsigned IdxWWidth        = cf_math_pkg::idx_width(WBufferDepth),
  parameter int unsigned IdxAwWidth       = cf_math_pkg::idx_width(NumPending),
  parameter type         addr_t           = logic [AddrWidth-1:0],
  parameter type         idx_w_t          = logic [IdxWWidth-1:0],
  parameter type         idx_aw_t         = logic [IdxAwWidth-1:0],
  parameter type         period_t         = logic [PeriodWidth-1:0],
  parameter type         budget_t         = logic [BudgetWidth-1:0]
)(
  input logic clk_i,
  input logic rst_ni,

  // Input / Slave Port
  input  axi_req_t  slv_req_i,
  output axi_resp_t slv_resp_o,

  // Output / Master Port
  output axi_req_t  mst_req_o,
  input  axi_resp_t mst_resp_i,

  // RT bypass
  input  logic rt_enable_i,
  output logic rt_bypassed_o,

  // fragmentation
  input  axi_pkg::len_t len_limit_i,

  // buffering
  output idx_w_t  num_w_pending_o,
  output idx_aw_t num_aw_pending_o,

  // address rules
  input  rt_rule_t [NumRules-1:0] rt_rule_i,
  output logic                    w_decode_error_o,
  output logic                    r_decode_error_o,

  // IMTU (bookkeeping)
  input  logic                         imtu_enable_i,
  input  logic                         imtu_abort_i,
  input  budget_t [NumAddrRegions-1:0] w_budget_i,
  output budget_t [NumAddrRegions-1:0] w_budget_left_o,
  input  period_t [NumAddrRegions-1:0] w_period_i,
  output period_t [NumAddrRegions-1:0] w_period_left_o,
  input  budget_t [NumAddrRegions-1:0] r_budget_i,
  output budget_t [NumAddrRegions-1:0] r_budget_left_o,
  input  period_t [NumAddrRegions-1:0] r_period_i,
  output period_t [NumAddrRegions-1:0] r_period_left_o,

  // isolation
  output logic isolate_o,
  output logic isolated_o
);


  /// the maximum amount of bytes one AXI transfer can have
  localparam int unsigned NumBytesWidth  =  axi_pkg::LenWidth + axi_pkg::SizeWidth + 32'd1;

  /// index with of the regions
  parameter int unsigned NumRegionWidth  = cf_math_pkg::idx_width(NumAddrRegions);

  /// maximum amount of bytes in a transfer type
  typedef logic[NumBytesWidth-1:0]  ax_bytes_t;

  /// maximum amount of bytes in a transfer type
  typedef logic[NumRegionWidth-1:0] region_idx_t;

  // internal buses
  axi_req_t  iso_req,  cut_req,  fwd_req,  mux_req;
  axi_resp_t iso_resp, cut_resp, fwd_resp, mux_resp;

  // number of bytes transferred via one ax
  ax_bytes_t aw_bytes;
  ax_bytes_t ar_bytes;

  // ax happen
  logic aw_happening;
  logic ar_happening;

  // which region has been selected
  region_idx_t aw_region;
  region_idx_t ar_region;

  // every address region and r/w has a counter and an isolate signal
  logic [NumAddrRegions-1:0] r_isolate;
  logic [NumAddrRegions-1:0] w_isolate;

  // global isolate
  logic global_isolate;

  // state enum of the bypass FSM
  typedef enum logic [1:0] {
    IDLE,
    ISOLATE,
    SWITCH,
    DEISOLATE
  } rt_state_e;

  // FSM state
  rt_state_e rt_state_d, rt_state_q;

  // FSM signals
  logic byp_isolate;

  // RT state
  logic rt_bypassed_d, rt_bypassed_q;


  // --------------------------------------------------
  // Bypass FSM
  // --------------------------------------------------
  // The bypass FSM will start in a bypassed state. The enable signal will activate it.

  always_comb begin : proc_fsm
    // default
    rt_state_d    = rt_state_q;
    rt_bypassed_d = rt_bypassed_q;
    byp_isolate   = 1'b0;

    case (rt_state_q)
      IDLE : begin
        if (rt_enable_i & rt_bypassed_q) begin
          rt_state_d = ISOLATE;
        end
        if (!rt_enable_i & !rt_bypassed_q) begin
          rt_state_d = ISOLATE;
        end
      end

      ISOLATE : begin
        byp_isolate = 1'b1;
        if (isolated_o) begin
          rt_state_d = SWITCH;
        end
      end

      SWITCH : begin
        byp_isolate = 1'b1;
        rt_bypassed_d = !rt_bypassed_q;
        rt_state_d = DEISOLATE;
      end

      DEISOLATE : begin
        if(!isolated_o) begin
          rt_state_d = IDLE;
        end
      end
    endcase
  end

  // connect output
  assign rt_bypassed_o = rt_bypassed_q;

  // state
  `FFARN(rt_state_q,    rt_state_d,    IDLE, clk_i, rst_ni)
  `FFARN(rt_bypassed_q, rt_bypassed_d, 1'b1, clk_i, rst_ni)


  // --------------------------------------------------
  // Isolation
  // --------------------------------------------------
  axi_isolate #(
    .NumPending           ( NumPending   ),
    .TerminateTransaction ( 1'b0         ),
    .AtopSupport          ( 1'b1         ),
    .AxiAddrWidth         ( AddrWidth    ),
    .AxiDataWidth         ( DataWidth    ),
    .AxiIdWidth           ( IdWidth      ),
    .AxiUserWidth         ( UserWidth    ),
    .axi_req_t            ( axi_req_t    ),
    .axi_resp_t           ( axi_resp_t   )
  ) i_axi_isolate (
    .clk_i,
    .rst_ni,
    .slv_req_i,
    .slv_resp_o,
    .mst_req_o  ( iso_req                      ),
    .mst_resp_i ( iso_resp                     ),
    .isolate_i  ( global_isolate | byp_isolate ),
    .isolated_o ( isolated_o                   )
  );

  // global isolate
  assign global_isolate = ((|r_isolate) | (|w_isolate)) & imtu_enable_i;
  assign isolate_o      = global_isolate;


  // --------------------------------------------------
  // Cut Transactions
  // --------------------------------------------------
  axi_gran_burst_splitter #(
    .MaxReadTxns  ( NumPending       ),
    .MaxWriteTxns ( NumPending       ),
    .AddrWidth    ( AddrWidth        ),
    .DataWidth    ( DataWidth        ),
    .IdWidth      ( IdWidth          ),
    .UserWidth    ( UserWidth        ),
    .CutPath      ( CutSplitterPaths ),
    .axi_req_t    ( axi_req_t        ),
    .axi_resp_t   ( axi_resp_t       ),
    .axi_aw_chan_t( aw_chan_t        ),
    .axi_w_chan_t ( w_chan_t         ),
    .axi_b_chan_t ( b_chan_t         ),
    .axi_ar_chan_t( ar_chan_t        ),
    .axi_r_chan_t ( r_chan_t         )
  ) i_axi_gran_burst_splitter (
    .clk_i,
    .rst_ni,
    .len_limit_i,
    .slv_req_i    ( mux_req  ),
    .slv_resp_o   ( mux_resp ),
    .mst_req_o    ( cut_req  ),
    .mst_resp_i   ( cut_resp )
  );


  // --------------------------------------------------
  // Buffer Transactions
  // --------------------------------------------------
  axi_write_buffer #(
    .NumOutstanding ( NumPending   ),
    .WBufferDepth   ( WBufferDepth ),
    .aw_chan_t      ( aw_chan_t    ),
    .w_chan_t       ( w_chan_t     ),
    .axi_req_t      ( axi_req_t    ),
    .axi_resp_t     ( axi_resp_t   )
  ) i_axi_write_buffer (
    .clk_i,
    .rst_ni,
    .slv_req_i       ( cut_req          ),
    .slv_resp_o      ( cut_resp         ),
    .mst_req_o       ( fwd_req          ),
    .mst_resp_i      ( fwd_resp         ),
    .num_w_stored_o  ( num_w_pending_o  ),
    .num_aw_stored_o ( num_aw_pending_o )
  );


  // --------------------------------------------------
  // Bandwidth Probes
  // --------------------------------------------------
  assign aw_bytes = ({1'b0, fwd_req.aw.len} + 9'h001) << (fwd_req.aw.size);
  assign ar_bytes = ({1'b0, fwd_req.ar.len} + 9'h001) << (fwd_req.ar.size);

  assign aw_happening = fwd_req.aw_valid & fwd_resp.aw_ready;
  assign ar_happening = fwd_req.ar_valid & fwd_resp.ar_ready;


  // --------------------------------------------------
  // Address Decoding
  // --------------------------------------------------
  logic w_decode_error, r_decode_error;

  addr_decode #(
    .NoIndices ( NumAddrRegions ),
    .NoRules   ( NumRules       ),
    .addr_t    ( addr_t         ),
    .rule_t    ( rt_rule_t      ),
    .Napot     ( 1'b0           )
  ) i_addr_decode_aw (
    .addr_i           ( fwd_req.aw.addr   ),
    .addr_map_i       ( rt_rule_i           ),
    .idx_o            ( aw_region           ),
    .dec_valid_o      ( /* NOT CONNECTED */ ),
    .dec_error_o      ( w_decode_error      ),
    .en_default_idx_i ( '0                  ),
    .default_idx_i    ( '0                  )
  );

  addr_decode #(
    .NoIndices ( NumAddrRegions ),
    .NoRules   ( NumRules       ),
    .addr_t    ( addr_t         ),
    .rule_t    ( rt_rule_t      ),
    .Napot     ( 1'b0           )
  ) i_addr_decode_ar (
    .addr_i           ( fwd_req.ar.addr   ),
    .addr_map_i       ( rt_rule_i           ),
    .idx_o            ( ar_region           ),
    .dec_valid_o      ( /* NOT CONNECTED */ ),
    .dec_error_o      ( r_decode_error      ),
    .en_default_idx_i ( '0                  ),
    .default_idx_i    ( '0                  )
  );

  if (CutDecErrors) begin : gen_decode_error_cuts
    // instantiate a register
    logic w_decode_error_q, r_decode_error_q;
    `FFARN(w_decode_error_q, w_decode_error, '0, clk_i, rst_ni)
    `FFARN(r_decode_error_q, r_decode_error, '0, clk_i, rst_ni)
    // connect outputs
    assign w_decode_error_o = w_decode_error_q;
    assign r_decode_error_o = r_decode_error_q;

  end else begin : no_gen_decode_error_cuts
    // connect outputs
    assign w_decode_error_o = w_decode_error;
    assign r_decode_error_o = r_decode_error;
  end


  // --------------------------------------------------
  // Bookkeeping
  // --------------------------------------------------
  for (genvar r = 0; r < NumAddrRegions; r++) begin : gen_regions
    // is the current region selected
    logic r_region_selected;
    logic w_region_selected;

    // the current region is selected if the index is equal to the region number
    assign r_region_selected = (ar_region == r);
    assign w_region_selected = (aw_region == r);

    ax_rt_unit_counter #(
      .PeriodWidth ( PeriodWidth ),
      .BudgetWidth ( BudgetWidth ),
      .ax_bytes_t  ( ax_bytes_t  )
    ) i_ax_rt_unit_counter_read (
      .clk_i,
      .rst_ni,
      .ax_bytes_i     ( ar_bytes                         ),
      .ax_happening_i ( ar_happening & r_region_selected ),
      .enable_i       ( imtu_enable_i                    ),
      .budget_i       ( r_budget_i      [r]              ),
      .budget_left_o  ( r_budget_left_o [r]              ),
      .budget_spent_o ( r_isolate       [r]              ),
      .period_i       ( r_period_i      [r]              ),
      .period_left_o  ( r_period_left_o [r]              ),
      .period_abort_i ( imtu_abort_i                     )
    );

    ax_rt_unit_counter #(
      .PeriodWidth ( PeriodWidth ),
      .BudgetWidth ( BudgetWidth ),
      .ax_bytes_t  ( ax_bytes_t  )
    ) i_ax_rt_unit_counter_write (
      .clk_i,
      .rst_ni,
      .ax_bytes_i     ( aw_bytes                         ),
      .ax_happening_i ( aw_happening & w_region_selected ),
      .enable_i       ( imtu_enable_i                    ),
      .budget_i       ( w_budget_i      [r]              ),
      .budget_left_o  ( w_budget_left_o [r]              ),
      .budget_spent_o ( w_isolate       [r]              ),
      .period_i       ( w_period_i      [r]              ),
      .period_left_o  ( w_period_left_o [r]              ),
      .period_abort_i ( imtu_abort_i                     )
    );
  end


  // --------------------------------------------------
  // Output
  // --------------------------------------------------
  assign mst_req_o  = rt_bypassed_q ? iso_req    : fwd_req;
  assign fwd_resp   = rt_bypassed_q ? '0         : mst_resp_i;
  assign iso_resp   = rt_bypassed_q ? mst_resp_i : mux_resp;
  assign mux_req    = rt_bypassed_q ? '0         : iso_req;

endmodule
