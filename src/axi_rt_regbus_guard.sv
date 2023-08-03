// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Thomas Benz <tbenz@ethz.ch>

`include "common_cells/registers.svh"

/// Restricts access to a downstream slave
module axi_rt_regbus_guard #(
  parameter int unsigned SubAddrWidth = 32'd0,
  parameter int unsigned RegIdWidth   = 32'd0,
  parameter int unsigned DataWidth    = 32'd0,
  parameter type         reg_req_t    = logic,
  parameter type         reg_rsp_t    = logic,
  // derived parameters
  parameter type         reg_id_t     = logic [RegIdWidth-1:0]
)(
  input  logic     clk_i,
  input  logic     rst_ni,
  // input port
  input  reg_id_t  id_i,
  input  reg_req_t req_i,
  output reg_rsp_t rsp_o,
  // output port
  output reg_req_t req_o,
  input  reg_rsp_t rsp_i
);

  // the state to keep
  typedef struct packed {
    reg_id_t id;
    logic    excl_w;
    logic    excl_r;
    logic    valid;
  } state_t;

  state_t state_d, state_q;

  // signals to the error slave, bus_guard register
  reg_req_t error_req, guard_req;
  reg_rsp_t error_rsp, guard_rsp;

  // select signal
  logic [1:0] select;

  // is the access allowed?
  logic block_access;


  // filter allowed and blocked requests
  reg_demux #(
    .NoPorts ( 32'd3     ),
    .req_t   ( reg_req_t ),
    .rsp_t   ( reg_rsp_t )
  ) i_reg_demux (
    .clk_i,
    .rst_ni,
    .in_select_i ( select                        ),
    .in_req_i    ( req_i                         ),
    .in_rsp_o    ( rsp_o                         ),
    .out_req_o   ( {guard_req, error_req, req_o} ),
    .out_rsp_i   ( {guard_rsp, error_rsp, rsp_i} )
  );

  // if we are not allowed to access: respond with an error
  reg_err_slv #(
    .DW      ( DataWidth  ),
    .ERR_VAL ( 'hbadca51e ),
    .req_t   ( reg_req_t  ),
    .rsp_t   ( reg_rsp_t  )
  ) i_reg_err_slv (
    .req_i   ( error_req  ),
    .rsp_o   ( error_rsp  )
  );


  // route the select signal depending on the condition
  always_comb begin : proc_demux_select
    // default: route to output
    select = 2'd0;

    // differentiate between the valid and invalid state
    if (!state_q.valid) begin
      // access to the special register
      if (req_i.addr[SubAddrWidth-1:0] == ('1 << 2)) begin
        select = 2'd2;
      // invalid access to a regular ID -> error
      end else begin
        select = 2'd1;
      end

    // if we have a valid ID stored: check it
    end else begin
      // the current ID is the claimed ID
      if (!block_access) begin
        // access to the special register
        if (req_i.addr[SubAddrWidth-1:0] == ('1 << 2)) begin
          select = 2'd2;
        end

      // the ID mismatches -> return an error
      end else begin
        select = 2'd1;
      end
    end
  end

  // understand if an access is blocked
  assign block_access = (state_q.excl_w &  req_i.write & state_q.id != id_i) |
                        (state_q.excl_r & !req_i.write & state_q.id != id_i);

  // implement read/write of the special register
  always_comb begin: proc_access_reg
    // default: store
    state_d = state_q;

    // we are always ready
    guard_rsp.ready = 1'b1;

    // write
    if (guard_req.valid & guard_req.wstrb[0] & guard_req.write) begin
      state_d.excl_w = guard_req.wdata[0];
      state_d.excl_r = guard_req.wdata[1];
      state_d.valid  = guard_req.wdata[2];
      state_d.id     = id_i;
    end

    // read
    guard_rsp.rdata    =  '0;
    guard_rsp.rdata[0] = state_q.excl_w;
    guard_rsp.rdata[1] = state_q.excl_r;
    guard_rsp.rdata[2] = state_q.valid;
    guard_rsp.error    = 1'b0;
  end

  // state
  `FFARN(state_q, state_d, '0, clk_i, rst_ni)

endmodule
