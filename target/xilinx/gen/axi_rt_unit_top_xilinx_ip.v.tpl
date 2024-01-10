// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Andreas Kurth <adk@lowrisc.org>
// - Alessandro Ottaviano <aottaviano@iis.ee.ethz.ch>

// This file was automatically generated with `rt_gen_xilinx.py`

/// Xilinx Wrapper for the AXI RT unit
module axi_rt_unit_top_xilinx_ip (\
  ${port('clk', 1, 1, False, False)},\
  ${port('rst', 1, 1, False, False, True)},\

  ${axi_ports('m_axi_rt_', True, rtcfg_aw, rtcfg_dw, rtcfg_iw, rtcfg_uw, int(rtcfg_num_mngrs), False)},

  ${axi_ports('s_axi_rt_', False, rtcfg_aw, rtcfg_dw, rtcfg_iw, rtcfg_uw, int(rtcfg_num_mngrs), False)},

  ${axi_lite_ports('s_axi_lite_rt_', False, rtcfg_law, rtcfg_ldw, 1, False)}
);

  // Number of managers
  localparam RtNumManagers  = ${rtcfg_num_mngrs};
  // Number of regions per manager
  localparam RtNumRegions   = ${rtcfg_num_regions};
  // Number of outstanding transactions
  localparam RtNumPending   = ${rtcfg_num_pending};
  // Depth of the Buffer
  localparam RtWBufferDepth = ${rtcfg_buf_depth};
  // Period width
  localparam RtPeriodWidth  = ${rtcfg_prd_width};
  // Budget width
  localparam RtBudgetWidth  = ${rtcfg_bdgt_width};
  // Enable internal cuts in the RT units
  localparam RtCutPaths     = ${rtcfg_cut_paths};
  // Enable transaction checks within the RT units
  localparam RtEnableChecks = ${rtcfg_en_checks};
  // Enable internal cuts (a flop) for decode errors
  localparam RtCutDecErrors = ${rtcfg_cut_decerr};
  // AXI configuration
  localparam RtAxiIdWidth   = ${rtcfg_iw};
  localparam RtAxiAddrWidth = ${rtcfg_aw};
  localparam RtAxiDataWidth = ${rtcfg_dw};
  localparam RtAxiUserWidth = ${rtcfg_uw};
  // AXI Lite configuration
  localparam RtAxiLiteAddrWidth = ${rtcfg_law};
  localparam RtAxiLiteDataWidth = ${rtcfg_ldw};
  // Register configuration
  localparam RtRegIdWidth   = ${rtcfg_riw};

  // AXI RT unit, xilinx wrapper
  axi_rt_unit_top_xilinx #(
    .RtNumManagers      ( RtNumManagers      ),
    .RtNumRegions   	( RtNumRegions	     ),
    .RtNumPending   	( RtNumPending	     ),
    .RtWBufferDepth 	( RtWBufferDepth     ),
    .RtPeriodWidth  	( RtPeriodWidth      ),
    .RtBudgetWidth  	( RtBudgetWidth      ),
    .RtCutPaths     	( RtCutPaths	     ),
    .RtEnableChecks 	( RtEnableChecks     ),
    .RtCutDecErrors     ( RtCutDecErrors     ),
    .RtAxiIdWidth   	( RtAxiIdWidth	     ),
    .RtAxiAddrWidth 	( RtAxiAddrWidth     ),
    .RtAxiDataWidth 	( RtAxiDataWidth     ),
    .RtAxiUserWidth 	( RtAxiUserWidth     ),
    .RtAxiLiteAddrWidth	( RtAxiLiteAddrWidth ),
    .RtAxiLiteDataWidth	( RtAxiLiteDataWidth ),
    .RtRegIdWidth       ( RtRegIdWidth       )
  ) i_axi_rt_unit_top_xilinx (
    ${port('clk', 1, 1, False, True)},\
    ${port('rst', 1, 1, False, True, True)},\

    ${axi_ports('m_axi_rt_', True, rtcfg_aw, rtcfg_dw, rtcfg_iw, rtcfg_uw, int(rtcfg_num_mngrs), True)},

    ${axi_ports('s_axi_rt_', False, rtcfg_aw, rtcfg_dw, rtcfg_iw, rtcfg_uw, int(rtcfg_num_mngrs), True)},

    ${axi_lite_ports('s_axi_lite_rt_', False, rtcfg_law, rtcfg_ldw, 1, True)}
  );

endmodule

<%def name="logic(width)">\
  <%
    if width == 1:
      typ = 'wire        '
    else:
      typ = "wire [%3d:0]" % (width - 1)
  %>
  ${typ}\
</%def>\
<%def name="port(name, width0, width1, output, conn=False, active_low=False)">\
  <%
  if output:
      direction = 'output'
      suffix = 'o'
  else:
      direction = 'input '
      suffix = 'i'
  if (width0 == 1 and width1 == 1):
      typ = '        '
  elif (width0 > 1 and width1 == 1):
      typ = "[%3d:0] " % (width0 - 1)
  elif (width0 == 1 and width1 > 1):
      typ = "[%3d:0] " % (width1 - 1)
  elif (width0 > 1 and width1 > 1):
      typ = "[%3d:0] [%3d:0]" % ((width0 - 1), (width1 - 1))
  else:
      print("width0 and width1 should be larger or equal to 1")
  if active_low:
      suffix = 'n' + suffix
  name = name + '_' + suffix
  %>
  %if not(conn):
    ${direction} ${typ} ${name}
  %else:
    .${name} (${name})
  %endif
</%def>\
<%def name="axi_ax_ports(prefix, master, aw, iw, uw, replica, conn)">\
  ${port(prefix + 'id', iw, replica, master, conn)},\
  ${port(prefix + 'addr', aw, replica, master, conn)},\
  ${port(prefix + 'len', 8, replica, master, conn)},\
  ${port(prefix + 'size', 3, replica, master, conn)},\
  ${port(prefix + 'burst', 2, replica, master, conn)},\
  ${port(prefix + 'lock', 1, replica, master, conn)},\
  ${port(prefix + 'cache', 4, replica, master, conn)},\
  ${port(prefix + 'prot', 3, replica, master, conn)},\
  ${port(prefix + 'qos', 4, replica, master, conn)},\
  ${port(prefix + 'user', uw, replica, master, conn)},\
  ${port(prefix + 'valid', 1, replica, master, conn)},\
  ${port(prefix + 'ready', 1, replica, not master, conn)}\
</%def>\
<%def name="axi_w_ports(prefix, master, dw, replica, conn)">\
  ${port(prefix + 'data', dw, replica, master, conn)},\
  ${port(prefix + 'strb', dw/8, replica, master, conn)},\
  ${port(prefix + 'last', 1, replica, master, conn)},\
  ${port(prefix + 'valid', 1, replica, master, conn)},\
  ${port(prefix + 'ready', 1, replica, not master, conn)}\
</%def>\
<%def name="axi_b_ports(prefix, master, iw, replica, conn)">\
  ${port(prefix + 'id', iw, replica, not master, conn)},\
  ${port(prefix + 'resp', 2, replica, not master, conn)},\
  ${port(prefix + 'valid', 1, replica, not master, conn)},\
  ${port(prefix + 'ready', 1, replica, master, conn)}\
</%def>\
<%def name="axi_r_ports(prefix, master, dw, iw, replica, conn)">\
  ${port(prefix + 'id', iw, replica, not master, conn)},\
  ${port(prefix + 'data', dw, replica, not master, conn)},\
  ${port(prefix + 'resp', 2, replica, not master, conn)},\
  ${port(prefix + 'last', 1, replica, not master, conn)},\
  ${port(prefix + 'valid', 1, replica, not master, conn)},\
  ${port(prefix + 'ready', 1, replica, master, conn)}\
</%def>\
<%def name="axi_ports(prefix, master, aw, dw, iw, uw, replica, conn)">\
  ${axi_ax_ports(prefix + 'aw', master, aw, iw, uw, replica, conn)},\
  ${axi_w_ports(prefix + 'w', master, dw, replica, conn)},\
  ${axi_b_ports(prefix + 'b', master, iw, replica, conn)},\
  ${axi_ax_ports(prefix + 'ar', master, aw, iw, uw, replica, conn)},\
  ${axi_r_ports(prefix + 'r', master, dw, iw, replica, conn)}\
</%def>\
<%def name="axi_lite_ax_ports(prefix, master, aw, replica, conn)">\
  ${port(prefix + 'addr', aw, replica, master, conn)},\
  ${port(prefix + 'prot', 3, replica, master, conn)},\
  ${port(prefix + 'valid', 1, replica, master, conn)},\
  ${port(prefix + 'ready', 1, replica, not master, conn)}\
</%def>\
<%def name="axi_lite_w_ports(prefix, master, dw, replica, conn)">\
  ${port(prefix + 'data', dw, replica, master, conn)},\
  ${port(prefix + 'strb', dw/8, replica, master, conn)},\
  ${port(prefix + 'valid', 1, replica, master, conn)},\
  ${port(prefix + 'ready', 1, replica, not master, conn)}\
</%def>\
<%def name="axi_lite_b_ports(prefix, master, replica, conn)">\
  ${port(prefix + 'resp', 2, replica, not master, conn)},\
  ${port(prefix + 'valid', 1, replica, not master, conn)},\
  ${port(prefix + 'ready', 1, replica, master, conn)}\
</%def>\
<%def name="axi_lite_r_ports(prefix, master, dw, replica, conn)">\
  ${port(prefix + 'data', dw, replica, not master, conn)},\
  ${port(prefix + 'resp', 2, replica, not master, conn)},\
  ${port(prefix + 'valid', 1, replica, not master, conn)},\
  ${port(prefix + 'ready', 1, replica, master, conn)}\
</%def>\
<%def name="axi_lite_ports(prefix, master, aw, dw, replica, conn)">\
  ${axi_lite_ax_ports(prefix + 'aw', master, aw, replica, conn)},\
  ${axi_lite_w_ports(prefix + 'w', master, dw, replica, conn)},\
  ${axi_lite_b_ports(prefix + 'b', master, replica, conn)},\
  ${axi_lite_ax_ports(prefix + 'ar', master, aw, replica, conn)},\
  ${axi_lite_r_ports(prefix + 'r', master, dw, replica, conn)}\
</%def>