// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Wolfgang Roenninger <wroennin@iis.ee.ethz.ch>
// - Andreas Kurth <akurth@iis.ee.ethz.ch>
// - Thomas Benz <tbenz@iis.ee.ethz.ch>

`include "common_cells/registers.svh"

/// Internal module of [`axi_gran_burst_splitter`](module.axi_gran_burst_splitter) to order transactions.
module axi_gran_burst_splitter_counters #(
  parameter int unsigned MaxTxns = 32'd0,
  parameter int unsigned IdWidth = 32'd0,
  parameter bit          CutPath =  1'b0,
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

  // the allocation interface can be cut
  typedef struct packed {
    id_t           id;
    axi_pkg::len_t len;
  } alloc_pld_t;

  alloc_pld_t alloc_pld_in, alloc_pld_out;
  logic       alloc_req;
  logic       alloc_gnt;

  assign alloc_pld_in.id  = alloc_id_i;
  assign alloc_pld_in.len = alloc_len_i;

  if (CutPath) begin : gen_spill
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
  end else begin : gen_no_spill
    assign alloc_req = alloc_req_i;
    assign alloc_gnt_o = alloc_gnt;
    assign alloc_pld_out = alloc_pld_in;
  end

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
      .delta_i    ( cnt_delta_i  ),
      .d_i        ( cnt_inp      ),
      .q_o        ( cnt_oup[i]   ),
      .overflow_o ( cnt_clr[i]   )
    );
    assign cnt_free[i] = (cnt_oup[i] < cnt_delta_i);
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
    .oup_id_i         ( cnt_id_i      ),
    .oup_pop_i        ( idq_oup_pop   ),
    .oup_req_i        ( cnt_req_i     ),
    .oup_data_o       ( cnt_r_idx     ),
    .oup_data_valid_o ( idq_oup_valid ),
    .oup_gnt_o        ( idq_oup_gnt   )
  );
  assign idq_inp_req = alloc_req   & alloc_gnt;
  assign alloc_gnt   = idq_inp_gnt & |(cnt_free);
  assign cnt_gnt_o   = idq_oup_gnt & idq_oup_valid;
  logic [8:0] read_len;
  assign read_len    = cnt_oup[cnt_r_idx] - 1;
  assign cnt_len_o   = read_len[7:0];

  assign idq_oup_pop = cnt_req_i & cnt_gnt_o & cnt_dec_i & (cnt_len_o < cnt_delta_i);
  always_comb begin
    cnt_dec            = '0;
    cnt_dec[cnt_r_idx] = cnt_req_i & cnt_gnt_o & cnt_dec_i;
  end
  always_comb begin
    cnt_set               = '0;
    cnt_set[cnt_free_idx] = alloc_req & alloc_gnt;
  end
  always_comb begin
    err_d     = err_q;
    cnt_err_o = err_q[cnt_r_idx];
    if (cnt_req_i && cnt_gnt_o && cnt_set_err_i) begin
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
