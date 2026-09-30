// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Chaoqun Liang <chaoqun.liang@unibo.it>

// handshake timeout monitor
// Monitors the window between VALID assertion and READY assertion
// Counts prescaled ticks while waiting for handshake
// Pre-handshake timeout monitor
// Monitors the window between VALID assertion and READY assertion
// Counts prescaled ticks while waiting for handshake

// Pre-handshake timeout monitor
// Monitors the window between VALID assertion and READY assertion
// Counts prescaled ticks while waiting for handshake

module tmu_hs_counter #(
  parameter type hs_cnt_t = logic,
  parameter type id_t     = logic
) (
  input  logic     clk_i,
  input  logic     rst_ni,
  input  logic     prescaled_en_i,  // Prescaled tick
  input  logic     valid_i,          // Channel VALID
  input  logic     ready_i,          // Channel READY
  input  id_t      id_i,             // Transaction ID
  input  hs_cnt_t  budget_i,         // Timeout budget (in prescaled ticks)
  output logic     timeout_o,        // Timeout pulse (1 cycle)
  output logic     reset_o,          // Request reset (same as timeout)
  output id_t      abort_id_o        // ID of timed-out transaction
);

  logic    armed_q, armed_n;
  hs_cnt_t cnt_q, cnt_n;
  id_t     id_q, id_n;
  logic    timeout_pulse;

  always_comb begin
    // Default: hold current state
    armed_n       = armed_q;
    cnt_n         = cnt_q;
    id_n          = id_q;
    timeout_pulse = 1'b0;

    // ARM: VALID asserted but READY not yet (handshake pending)
    if (valid_i && !ready_i && !armed_q) begin
      armed_n = 1'b1;
      cnt_n   = '0;
      id_n    = id_i;  // Capture ID at arm time (stable for reporting)
    end 
    // ARMED STATE: Count or disarm
    else if (armed_q) begin
      // DISARM: Handshake completes
      if (valid_i && ready_i) begin
        armed_n = 1'b0;
        cnt_n   = '0;
        // id_q remains stable (don't care after disarm)
      end 
      // COUNT: Increment on prescaler tick
      else if (prescaled_en_i) begin
        if (cnt_q < budget_i) begin
          cnt_n = cnt_q + 1'b1;
        end else begin
          // Timeout detected: counter reached budget
          timeout_pulse = 1'b1;
          // Counter stops incrementing, stays at budget
          // Remains armed until handshake or reset
        end
      end
    end
  end

  // State registers
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      armed_q <= 1'b0;
      cnt_q   <= '0;
      id_q    <= '0;
    end else begin
      armed_q <= armed_n;
      cnt_q   <= cnt_n;
      id_q    <= id_n;
    end
  end

  // Outputs
  assign timeout_o  = timeout_pulse;  // Single-cycle pulse when budget reached
  assign reset_o    = timeout_pulse;  // Same signal (can be used as reset trigger)
  assign abort_id_o = id_q;           // Captured ID (valid when timeout asserts)

endmodule
