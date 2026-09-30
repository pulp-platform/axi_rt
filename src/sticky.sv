// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Chaoqun Liang <chaoqun.liang@unibo.it>

// we want to stick any event that happens between ticks
// and then present (and clear) it on the next tick
// Sticky module: Capture signal immediately, hold until tick release
//
// Behavior:
// - Output goes HIGH as soon as input goes HIGH (combinational)
// - Output stays HIGH (latched) even if input drops
// - Output is cleared/released on tick (release_i)
// - If input is HIGH when tick arrives, output stays HIGH

module sticky (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic release_i,   // prescaled tick - clears the latch
  input  logic sticky_i,    // input signal to capture
  output logic sticky_o     // output: immediate + sticky until release
);

  logic sticky_reg;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sticky_reg <= 1'b0;
    end else if (release_i) begin
      // On tick: clear the sticky bit
      // Will immediately re-set if input is still high (via combinational output)
      sticky_reg <= 1'b0;
    end else if (sticky_i) begin
      // Capture: latch high when input goes high
      sticky_reg <= 1'b1;
    end
    // else: hold current state
  end

  // Combinational output: immediate response to input OR latched state
  assign sticky_o = sticky_i | sticky_reg;

endmodule
