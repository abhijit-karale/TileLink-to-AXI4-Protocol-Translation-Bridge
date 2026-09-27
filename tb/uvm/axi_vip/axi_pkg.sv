//==============================================================================
// File: axi_pkg.sv
// Description: UVM Package for AXI4 Verification IP
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef AXI_PKG_SV
`define AXI_PKG_SV

package axi_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import tl_axi4_pkg::*;

  `include "axi_seq_item.sv"
  `include "axi_driver.sv"
  `include "axi_monitor.sv"
  `include "axi_sequencer.sv"
  `include "axi_agent.sv"

endpackage : axi_pkg

`endif // AXI_PKG_SV
