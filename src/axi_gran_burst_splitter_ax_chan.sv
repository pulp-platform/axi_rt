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
// - Thomas Benz <tbenz@iis.ee.ethz.ch>

`include "common_cells/registers.svh"

/// Internal module of [`axi_gran_burst_splitter`](module.axi_gran_burst_splitter) to control Ax channels.
///
/// Store burst lengths in counters, which are associated to AXI IDs through ID queues (to allow
/// reordering of responses w.r.t. requests).
module axi_gran_burst_splitter_ax_chan #(
  parameter type         chan_t  = logic,
  parameter int unsigned IdWidth = 0,
  parameter int unsigned MaxTxns = 0,
  parameter type         id_t    = logic[IdWidth-1:0]
) (
  input  logic          clk_i,
  input  logic          rst_ni,

  // length
  input  axi_pkg::len_t len_limit_i,

  input  chan_t         ax_i,
  input  logic          ax_valid_i,
  output logic          ax_ready_o,
  output chan_t         ax_o,
  output logic          ax_valid_o,
  input  logic          ax_ready_i,

  input  id_t           cnt_id_i,
  output axi_pkg::len_t cnt_len_o,
  input  logic          cnt_set_err_i,
  output logic          cnt_err_o,
  input  logic          cnt_dec_i,
  input  logic          cnt_req_i,
  output logic          cnt_gnt_o
);
  typedef logic[IdWidth-1:0]           cnt_id_t;
  typedef logic[axi_pkg::LenWidth:0] num_beats_t;

  chan_t      ax_d, ax_q;
  // keep the number of remaining beats. != len
  num_beats_t num_beats_d, num_beats_q;
  // maximum number of beats to subtract in one go
  num_beats_t max_beats;


  logic cnt_alloc_req, cnt_alloc_gnt;
  axi_gran_burst_splitter_counters #(
    .MaxTxns ( MaxTxns  ),
    .IdWidth ( IdWidth  )
  ) i_axi_gran_burst_splitter_counters (
    .clk_i,
    .rst_ni,
    .alloc_id_i     ( ax_i.id       ),
    .alloc_len_i    ( ax_i.len      ),
    .alloc_req_i    ( cnt_alloc_req ),
    .alloc_gnt_o    ( cnt_alloc_gnt ),
    .cnt_id_i       ( cnt_id_i      ),
    .cnt_len_o      ( cnt_len_o     ),
    .cnt_set_err_i  ( cnt_set_err_i ),
    .cnt_err_o      ( cnt_err_o     ),
    .cnt_dec_i      ( cnt_dec_i     ),
    .cnt_delta_i    ( max_beats     ),
    .cnt_req_i      ( cnt_req_i     ),
    .cnt_gnt_o      ( cnt_gnt_o     )
  );

  // assign the max_beats depending on the limit value. Limit value is given as an AXI len.
  // limit = 0 means one beat each AX
  assign max_beats = {1'b0, len_limit_i} + 9'h001;

  enum logic {Idle, Busy} state_d, state_q;
  always_comb begin
    cnt_alloc_req = 1'b0;
    ax_d          = ax_q;
    state_d       = state_q;
    num_beats_d   = num_beats_q;
    ax_o          = '0;
    ax_valid_o    = 1'b0;
    ax_ready_o    = 1'b0;
    unique case (state_q)
      Idle: begin
        if (ax_valid_i && cnt_alloc_gnt) begin

          // No splitting required -> feed through.
          if (ax_i.len <= len_limit_i) begin
            ax_o          = ax_i;
            ax_valid_o    = 1'b1;
            // As soon as downstream is ready, allocate a counter and acknowledge upstream.
            if (ax_ready_i) begin
              cnt_alloc_req = 1'b1;
              ax_ready_o    = 1'b1;
            end

          // Splitting required.
          end else begin
            // Store Ax, allocate a counter, and acknowledge upstream.
            ax_d          = ax_i;
            cnt_alloc_req = 1'b1;
            ax_ready_o    = 1'b1;
            // As burst is too long, we will need to send multiple
            state_d = Busy;
            num_beats_d = ({1'b0, ax_i.len} + 9'h001);
            // Try to feed first burst through.
            ax_o          = ax_d;
            // if we are here we can send the length limit once for sure
            ax_o.len      = len_limit_i;
            ax_valid_o    = 1'b1;
            if (ax_ready_i) begin
              // Reduce number of bursts still to be sent by one and increment address.
              num_beats_d = ({1'b0, ax_i.len} + 9'h001) - max_beats;
              if (ax_d.burst == axi_pkg::BURST_INCR) begin
                // modify the address
                ax_d.addr += (1 << ax_d.size) * max_beats;
              end
            end
          end
        end
      end
      Busy: begin
        // Sent next burst from split.
        ax_o       = ax_q;
        ax_valid_o = 1'b1;
        // emit the proper length
        if (num_beats_q <= max_beats) begin
          // this is the remainder
          ax_o.len = axi_pkg::len_t'(num_beats_q - 9'h001);
        end else begin
          ax_o.len = len_limit_i;
        end
        // next state
        if (ax_ready_i) begin
          if (num_beats_q <= max_beats) begin
            // If this was the last burst, go back to idle.
            state_d = Idle;
          end else begin
            // Otherwise, continue with the next burst.
            num_beats_d = num_beats_q - max_beats;
            if (ax_q.burst == axi_pkg::BURST_INCR) begin
              ax_d.addr += (1 << ax_q.size) * max_beats;
            end
          end
        end
      end
      default: /*do nothing*/;
    endcase
  end

  // registers
  `FFARN(ax_q, ax_d, '0, clk_i, rst_ni)
  `FFARN(state_q, state_d, Idle, clk_i, rst_ni)
  `FFARN(num_beats_q, num_beats_d, 9'h000, clk_i, rst_ni)
endmodule
