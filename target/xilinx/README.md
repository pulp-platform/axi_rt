# FPGA mapping and IP packaging in Xilinx environment

AXI RT can be packaged in the Xilinx Vivado environment.

Although being a per-manager IP, each AXI RT unit (`src/axi_rt_unit.sv`) shares
the same register file. In addition, a *bus guard* unit guards transaction
owners.

This architecture makes it easier to package each AXI RT unit (one per manager)
together with the bus guard and the configuration register file
(`src/axi_rt_unit_top.sv`).

The AXI RT IP has a standard interface compatible with common Xilinx IPs:

* **`m_axi_rt` and `s_axi_rt`**: manager and subordinate AXI4 ports. The width of
  these interfaces is `AXIRT_NUM_MGRS` from the main `axirt.mk` make fragment
* **`s_axi_lite_rt`**: a convenience subordinate AXI-Lite interface for the register
  file configuration
* **`clk_i`**: clock of AXI RT IP
* **`rst_ni`**: reset (active low) of AXI RT IP

Currently, the (pure) Verilog xilinx top level wrapper is autogenerated from a
template to instantiate the desired number of AXI4 manager ports.

---
**Note for the reader**

The top level currently checked in this repository is configured with 2 manager
ports and 1 subordinate region.

## Getting started

To generate the xilinx top level wrapper, from the repository root type:

```
make -B AXIRT_NUM_MGRS=<your_value> AXIRT_NUM_SUBS=<your_value> target/xilinx/src/axi_rt_unit_top_xilinx_ip.v
```

Subsequently, package the IP:

```
make axirt-xil-all
```

The packaged IP will be generated in the `target/xilinx/axirt_ip` directory. By
default, the IP is generated with Vivado in batch mode. To use the GUI, append
`VIVADO_MODE=gui` to the previous make command.

---

**Note for the reader**

In the future, the top level Verilog wrapper could be made configurable with
parameters using Xilinx directives, so that the number of manager ports can be
chosen when instantiating the IP in a block design. This feature is *currently*
not provided.

## Adding AXI RT IP to a block design

To add AXI RT IP to a block design, source `scripts/add_axirt_ip.tcl` during the
block design creation flow. This will add the folder `target/xilinx/axirt_ip` in
the Xilinx IP catalog, and will instantiate AXI RT in the block design.