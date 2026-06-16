// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Thomas Benz <tbenz@ethz.ch>
// - Tim Fischer <fischeti@iis.ee.ethz.ch>

`include "common_cells/registers.svh"

/// Restricts access to a downstream APB slave based on a claimed ID.
///
/// A special "claim" register is mapped to the top word of the guard's APB
/// address space (`SubAddrWidth` bits wide). Software claims exclusive read
/// and/or write access by writing this register; once claimed, accesses from a
/// different ID are rejected with an APB error response.
module axi_rt_regbus_guard #(
  parameter int unsigned SubAddrWidth = 32'd0,
  parameter int unsigned RegIdWidth   = 32'd0,
  parameter int unsigned DataWidth    = 32'd0,
  parameter type         apb_req_t    = logic,
  parameter type         apb_resp_t   = logic,
  // derived parameters
  parameter type         reg_id_t     = logic [RegIdWidth-1:0]
)(
  input  logic      clk_i,
  input  logic      rst_ni,
  // input port
  input  reg_id_t   id_i,
  input  apb_req_t  req_i,
  output apb_resp_t rsp_o,
  // output port
  output apb_req_t  req_o,
  input  apb_resp_t rsp_i
);

  // Address of the special claim register: the top word of the address space
  // (all ones with the two byte-offset bits cleared), matching the legacy
  // register-interface guard scheme.
  localparam logic [SubAddrWidth-1:0] ClaimAddr = {{(SubAddrWidth-2){1'b1}}, 2'b00};

  // the state to keep
  typedef struct packed {
    reg_id_t id;
    logic    excl_w;
    logic    excl_r;
    logic    valid;
  } state_t;

  state_t state_d, state_q;

  // signals to the error slave and claim register
  apb_req_t  error_req, claim_req;
  apb_resp_t error_rsp, claim_rsp;

  // select signal: 0 -> downstream (passthrough), 1 -> error, 2 -> claim
  logic [1:0] select;

  // is the access blocked?
  logic block_access;


  // filter allowed and blocked requests
  apb_demux #(
    .NoMstPorts ( 32'd3      ),
    .req_t      ( apb_req_t  ),
    .resp_t     ( apb_resp_t )
  ) i_apb_demux (
    .slv_req_i  ( req_i                         ),
    .slv_resp_o ( rsp_o                         ),
    .mst_req_o  ( {claim_req, error_req, req_o} ),
    .mst_resp_i ( {claim_rsp, error_rsp, rsp_i} ),
    .select_i   ( select                        )
  );

  // if we are not allowed to access: respond with an error
  apb_err_slv #(
    .req_t     ( apb_req_t   ),
    .resp_t    ( apb_resp_t  ),
    .RespWidth ( DataWidth   ),
    .RespData  ( 32'hBADCAB1E )
  ) i_apb_err_slv (
    .slv_req_i  ( error_req ),
    .slv_resp_o ( error_rsp )
  );


  // route the select signal depending on the condition
  always_comb begin : proc_demux_select
    // default: route to downstream output
    select = 2'd0;

    // differentiate between the valid and invalid state
    if (!state_q.valid) begin
      // access to the special register
      if (req_i.paddr[SubAddrWidth-1:0] == ClaimAddr) begin
        select = 2'd2;
      // invalid access while no ID is claimed -> error
      end else begin
        select = 2'd1;
      end

    // if we have a valid ID stored: check it
    end else begin
      // the current ID is the claimed ID
      if (!block_access) begin
        // access to the special register
        if (req_i.paddr[SubAddrWidth-1:0] == ClaimAddr) begin
          select = 2'd2;
        end

      // the ID mismatches -> return an error
      end else begin
        select = 2'd1;
      end
    end
  end

  // understand if an access is blocked
  assign block_access = (state_q.excl_w &  req_i.pwrite & (state_q.id != id_i)) |
                        (state_q.excl_r & !req_i.pwrite & (state_q.id != id_i));

  // implement read/write of the special claim register (a tiny APB slave)
  always_comb begin: proc_access_reg
    // default: store
    state_d = state_q;

    // a write completes in the APB access phase (psel & penable)
    if (claim_req.psel & claim_req.penable & claim_req.pwrite & claim_req.pstrb[0]) begin
      state_d.excl_w = claim_req.pwdata[0];
      state_d.excl_r = claim_req.pwdata[1];
      state_d.valid  = claim_req.pwdata[2];
      state_d.id     = id_i;
    end
  end

  // claim register read data and handshake (always ready, never errors)
  always_comb begin : proc_claim_rsp
    claim_rsp.prdata    =  '0;
    claim_rsp.prdata[0] = state_q.excl_w;
    claim_rsp.prdata[1] = state_q.excl_r;
    claim_rsp.prdata[2] = state_q.valid;
    claim_rsp.pready    = 1'b1;
    claim_rsp.pslverr   = 1'b0;
  end

  // state
  `FFARN(state_q, state_d, '0, clk_i, rst_ni)

endmodule
