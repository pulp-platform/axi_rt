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

/// Internal module of [`axi_gran_burst_splitter`](module.axi_gran_burst_splitter) to order transactions.
module axi_gran_burst_splitter_counters #(
  parameter int unsigned MaxTxns = 0,
  parameter int unsigned IdWidth = 0,
  parameter type         id_t    = logic [IdWidth-1:0],
  parameter type         cnt_t   = logic [axi_pkg::LenWidth:0]
) (
  input  logic          clk_i,
  input  logic          rst_ni,

  input  id_t           alloc_id_i,
  input  axi_pkg::len_t alloc_len_i,
  input  logic          alloc_req_i,
  output logic          alloc_gnt_o,

  input  id_t           cnt_id_i,
  output axi_pkg::len_t cnt_len_o,
  input  logic          cnt_set_err_i,
  output logic          cnt_err_o,
  input  logic          cnt_dec_i,
  input  cnt_t          cnt_delta_i,
  input  logic          cnt_req_i,
  output logic          cnt_gnt_o
);

  typedef struct packed {
    id_t           id;
    axi_pkg::len_t len;
  } alloc_pld_t;

  alloc_pld_t alloc_pld_in, alloc_pld_out;
  logic       alloc_req;
  logic       alloc_gnt;

  assign alloc_pld_in.id  = alloc_id_i;
  assign alloc_pld_in.len = alloc_len_i;

  spill_register #(
    .T      ( alloc_pld_t ),
    .Bypass ( 1'b0        )
  ) i_spill_register_alloc (
    .clk_i,
    .rst_ni,
    .valid_i ( alloc_req_i   ),
    .ready_o ( alloc_gnt_o   ),
    .data_i  ( alloc_pld_in  ),
    .valid_o ( alloc_req     ),
    .ready_i ( alloc_gnt     ),
    .data_o  ( alloc_pld_out )
  );

  // assign alloc_req = alloc_req_i;
  // assign alloc_gnt_o = alloc_gnt;
  // assign alloc_pld_out = alloc_pld_in;

  typedef struct packed {
    id_t           id;
    logic          dec;
    cnt_t          delta;
  } cnt_pld_t;

  cnt_pld_t cnt_pld_in, cnt_pld_out;
  logic       cnt_req;
  logic       cnt_gnt;

  assign cnt_pld_in.id    = cnt_id_i;
  assign cnt_pld_in.dec   = cnt_dec_i;
  assign cnt_pld_in.delta = cnt_delta_i;

  // spill_register #(
  //   .T      ( cnt_pld_t   ),
  //   .Bypass ( 1'b0        )
  // ) i_spill_register_cnt (
  //   .clk_i,
  //   .rst_ni,
  //   .valid_i ( cnt_req_i   ),
  //   .ready_o ( cnt_gnt_o   ),
  //   .data_i  ( cnt_pld_in  ),
  //   .valid_o ( cnt_req     ),
  //   .ready_i ( cnt_gnt     ),
  //   .data_o  ( cnt_pld_out )
  // );

  assign cnt_req = cnt_req_i;
  assign cnt_gnt_o = cnt_gnt;
  assign cnt_pld_out = cnt_pld_in;

  localparam int unsigned CntIdxWidth = (MaxTxns > 1) ? $clog2(MaxTxns) : 32'd1;
  typedef logic [CntIdxWidth-1:0]         cnt_idx_t;
  logic [MaxTxns-1:0]  cnt_dec, cnt_free, cnt_set, err_d, err_q, cnt_clr;
  cnt_t                cnt_inp;
  cnt_t [MaxTxns-1:0]  cnt_oup;
  cnt_idx_t            cnt_free_idx, cnt_r_idx;
  for (genvar i = 0; i < MaxTxns; i++) begin : gen_cnt
    delta_counter #(
      .WIDTH ( $bits(cnt_t) )
    ) i_cnt (
      .clk_i,
      .rst_ni,
      .clear_i    ( cnt_clr[i]   ),
      .en_i       ( cnt_dec[i]   ),
      .load_i     ( cnt_set[i]   ),
      .down_i     ( 1'b1         ),
      .delta_i    ( cnt_pld_out.delta  ),
      .d_i        ( cnt_inp      ),
      .q_o        ( cnt_oup[i]   ),
      .overflow_o ( cnt_clr[i]   )
    );
    assign cnt_free[i] = (cnt_oup[i] < cnt_pld_out.delta);
  end
  assign cnt_inp = {1'b0, alloc_pld_out.len} + 1;

  lzc #(
    .WIDTH  ( MaxTxns ),
    .MODE   ( 1'b0    )  // start counting at index 0
  ) i_lzc (
    .in_i    ( cnt_free     ),
    .cnt_o   ( cnt_free_idx ),
    .empty_o (              )
  );

  logic idq_inp_req, idq_inp_gnt,
        idq_oup_gnt, idq_oup_valid, idq_oup_pop;
  id_queue #(
    .ID_WIDTH ( $bits(id_t) ),
    .CAPACITY ( MaxTxns     ),
    .FULL_BW  ( 1'b1        ),
    .data_t   ( cnt_idx_t   )
  ) i_idq (
    .clk_i,
    .rst_ni,
    .inp_id_i         ( alloc_pld_out.id ),
    .inp_data_i       ( cnt_free_idx  ),
    .inp_req_i        ( idq_inp_req   ),
    .inp_gnt_o        ( idq_inp_gnt   ),
    .exists_data_i    ( '0            ),
    .exists_mask_i    ( '0            ),
    .exists_req_i     ( 1'b0          ),
    .exists_o         (/* keep open */),
    .exists_gnt_o     (/* keep open */),
    .oup_id_i         ( cnt_pld_out.id      ),
    .oup_pop_i        ( idq_oup_pop   ),
    .oup_req_i        ( cnt_req     ),
    .oup_data_o       ( cnt_r_idx     ),
    .oup_data_valid_o ( idq_oup_valid ),
    .oup_gnt_o        ( idq_oup_gnt   )
  );
  assign idq_inp_req = alloc_req   & alloc_gnt;
  assign alloc_gnt   = idq_inp_gnt & |(cnt_free);
  assign cnt_gnt     = idq_oup_gnt & idq_oup_valid;
  logic [8:0] read_len;
  assign read_len    = cnt_oup[cnt_r_idx] - 1;
  assign cnt_len_o   = read_len[7:0];

  assign idq_oup_pop = cnt_req & cnt_gnt & cnt_pld_out.dec & (cnt_len_o < cnt_pld_out.delta);
  always_comb begin
    cnt_dec            = '0;
    cnt_dec[cnt_r_idx] = cnt_req & cnt_gnt & cnt_pld_out.dec;
  end
  always_comb begin
    cnt_set               = '0;
    cnt_set[cnt_free_idx] = alloc_req & alloc_gnt;
  end
  always_comb begin
    err_d     = err_q;
    cnt_err_o = err_q[cnt_r_idx];
    if (cnt_req && cnt_gnt && cnt_set_err_i) begin
      err_d[cnt_r_idx] = 1'b1;
      cnt_err_o        = 1'b1;
    end
    if (alloc_req && alloc_gnt) begin
      err_d[cnt_free_idx] = 1'b0;
    end
  end

  // registers
  `FFARN(err_q, err_d, '0, clk_i, rst_ni)

  `ifndef VERILATOR
  // pragma translate_off
  assume property (@(posedge clk_i) idq_oup_gnt |-> idq_oup_valid)
    else $warning("Invalid output at ID queue, read not granted!");
  // pragma translate_on
  `endif

endmodule
