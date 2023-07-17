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
// - Thomas Benz <enz@ethz.ch>

`include "axi/typedef.svh"
`include "axi/assign.svh"
`include "axi-rt/assign.svh"
`include "axi-rt/ports.svh"

/// Synth Wrapper for the AXI RT unit
/// Codename `Mr Poopybutthole`
module axi_rt_unit_synth #(
  parameter int unsigned PeriodWidth    = 32'd0,
  parameter int unsigned BudgetWidth    = 32'd0,
  parameter int unsigned WBufferDepth   = 32'd0,
  parameter int unsigned NumPending     = 32'd0,
  parameter int unsigned AxiIdWidth     = 32'd0,
  parameter int unsigned AxiAddrWidth   = 32'd0,
  parameter int unsigned AxiDataWidth   = 32'd0,
  parameter int unsigned AxiUserWidth   = 32'd0,
  parameter int unsigned NumAddrRegions = 32'd0,
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
  parameter type addr_t                 = logic    [AxiAddrWidth-1  :0],
  parameter type data_t                 = logic    [AxiDataWidth-1  :0],
  parameter type strb_t                 = logic    [AxiDataWidth/8-1:0],
  parameter type user_t                 = logic    [AxiUserWidth-1  :0]
) (

  input  logic          clk_i,
  input  logic          rst_ni,

  `AXI_M_PORTS(rt, addr_t, data_t, strb_t, id_t, user_t, user_t, user_t, user_t, user_t)
  `AXI_S_PORTS(rt, addr_t, data_t, strb_t, id_t, user_t, user_t, user_t, user_t, user_t)

  input  logic          rt_enable_i,
  output logic          rt_bypassed_o,
  input  axi_pkg::len_t len_limit_i,

  output idx_w_t        num_w_pending_o,
  output idx_aw_t       num_aw_pending_o,

  output logic          w_decode_error_o,
  output logic          r_decode_error_o,
  input  logic          imtu_enable_i,
  input  logic          imtu_abort_i,

  input  budget_array_t r_budget_i,
  output budget_array_t r_budget_left_o,
  input  period_array_t r_period_i,
  output period_array_t r_period_left_o,
  input  budget_array_t w_budget_i,
  output budget_array_t w_budget_left_o,
  input  period_array_t w_period_i,
  output period_array_t w_period_left_o,
  output logic          isolate_o,
  output logic          isolated_o
);

  `AXI_TYPEDEF_ALL(axi, addr_t, id_t, data_t, strb_t, user_t)

  axi_req_t  m_req, s_req;
  axi_resp_t m_rsp, s_rsp;

  `AXI_ASSIGN_MASTER_TO_FLAT(rt, m_req, m_rsp)
  `AXI_ASSIGN_SLAVE_TO_FLAT (rt, s_req, s_rsp)

    /// rule type
  typedef struct packed {
    logic [7:0] idx;
    addr_t      start_addr;
    addr_t      end_addr;
  } rt_rule_t;

  // Each slave has its own address range:
  localparam rt_rule_t [NumAddrRegions-1:0] AddrMap = addr_map_gen();

  function automatic rt_rule_t [NumAddrRegions-1:0] addr_map_gen ();
    for (int unsigned i = 0; i < NumAddrRegions; i++) begin
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
  axi_rt_unit #(
    .AddrWidth      ( AxiAddrWidth     ),
    .DataWidth      ( AxiDataWidth     ),
    .IdWidth        ( AxiIdWidth       ),
    .UserWidth      ( AxiUserWidth     ),
    .NumPending     ( NumPending       ),
    .WBufferDepth   ( WBufferDepth     ),
    .NumAddrRegions ( NumAddrRegions   ),
    .NumRules       ( NumAddrRegions   ),
    .BudgetWidth    ( BudgetWidth      ),
    .PeriodWidth    ( PeriodWidth      ),
    .rt_rule_t      ( rt_rule_t        ),
    .addr_t         ( addr_t           ),
    .aw_chan_t      ( axi_aw_chan_t    ),
    .ar_chan_t      ( axi_ar_chan_t    ),
    .w_chan_t       ( axi_w_chan_t     ),
    .b_chan_t       ( axi_b_chan_t     ),
    .r_chan_t       ( axi_r_chan_t     ),
    .axi_req_t      ( axi_req_t        ),
    .axi_resp_t     ( axi_resp_t       )
  ) i_axi_rt_unit (
    .clk_i,
    .rst_ni,
    .slv_req_i        ( s_req         ),
    .slv_resp_o       ( s_rsp         ),
    .mst_req_o        ( m_req         ),
    .mst_resp_i       ( m_rsp         ),
    .rt_enable_i,
    .rt_bypassed_o,
    .len_limit_i,
    .num_w_pending_o,
    .num_aw_pending_o,
    .rt_rule_i        ( AddrMap       ),
    .w_decode_error_o,
    .r_decode_error_o,
    .imtu_enable_i,
    .imtu_abort_i,
    .r_budget_i,
    .r_budget_left_o,
    .r_period_i,
    .r_period_left_o,
    .w_budget_i,
    .w_budget_left_o,
    .w_period_i,
    .w_period_left_o,
    .isolate_o,
    .isolated_o
  );

endmodule
