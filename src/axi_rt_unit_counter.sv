// Copyright (c) 2023 ETH Zurich, University of Bologna
//
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

/// Counter unit of RT unit
module ax_rt_unit_counter #(
  parameter int unsigned PeriodWidth = 32'd0,
  parameter int unsigned BudgetWidth = 32'd0,
  parameter type         ax_bytes_t  = logic,
  parameter type         period_t    = logic[PeriodWidth-1:0],
  parameter type         budget_t    = logic[BudgetWidth-1:0]
)(
  input  logic      clk_i,
  input  logic      rst_ni,
  input  ax_bytes_t ax_bytes_i,
  input  logic      ax_happening_i,
  input  logic      enable_i,
  input  budget_t   budget_i,
  output budget_t   budget_left_o,
  output logic      budget_spent_o,
  input  period_t   period_i,
  output period_t   period_left_o,
  input  logic      period_abort_i
);

  // --------------------------------------------------
  // Period Tracking
  // --------------------------------------------------
  logic period_over;
  logic period_load;

  period_t static_delat_one = 'd1;

  delta_counter #(
    .WIDTH           ( PeriodWidth ),
    .STICKY_OVERFLOW ( 1'b0        )
  ) i_delta_counter_period (
    .clk_i,
    .rst_ni,
    .clear_i   ( 1'b0                ),
    .en_i      ( enable_i            ),
    .load_i    ( period_load         ),
    .down_i    ( 1'b1                ),
    .delta_i   ( static_delat_one    ),
    .d_i       ( period_i            ),
    .q_o       ( period_left_o       ),
    .overflow_o( /* NOT CONNECTED */ )
  );

  // load period new
  assign period_load = period_over | period_abort_i;

  // period expired
  assign period_over = (period_left_o == '0);


  // --------------------------------------------------
  // Budget Tracking
  // --------------------------------------------------
  budget_t bytes_spent;
  logic    budget_en;
  logic    budget_overflow;

  delta_counter #(
    .WIDTH           ( BudgetWidth ),
    .STICKY_OVERFLOW ( 1'b0        )
  ) i_delta_counter_budget (
    .clk_i,
    .rst_ni,
    .clear_i   ( 1'b0            ),
    .en_i      ( budget_en       ),
    .load_i    ( period_over     ),
    .down_i    ( 1'b1            ),
    .delta_i   ( bytes_spent     ),
    .d_i       ( budget_i        ),
    .q_o       ( budget_left_o   ),
    .overflow_o( budget_overflow )
  );

  // explicit cast
  assign bytes_spent = budget_t'(ax_bytes_i);

  // enable budget counter
  assign budget_en = enable_i & !budget_spent_o & ax_happening_i;

  // no more budget left :(
  assign budget_spent_o = (budget_left_o == '0) | budget_overflow;

endmodule
