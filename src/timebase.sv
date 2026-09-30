// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Chaoqun Liang <chaoqun.liang@unibo.it>

module timebase #(
  parameter int unsigned DivFactor = 1
)(
    input logic clk_i,
    input logic rst_ni,
    output logic tick_o
  );

  if (DivFactor == 1) begin : gen_div1
    // pulse every cycle
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) tick_o <= 1'b0;
      else         tick_o <= 1'b1;
    end
  end else begin : gen_divN
    localparam int W = $clog2(DivFactor);
    logic [W-1:0] counter;

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        counter <= '0;
        tick_o <= 1'b1;
      end else if (counter == DivFactor-1) begin
        counter <= '0;
        tick_o <= 1'b1;
      end else begin
        counter <= counter + 1'b1;
        tick_o <= 1'b0;
      end
    end
  end
endmodule
