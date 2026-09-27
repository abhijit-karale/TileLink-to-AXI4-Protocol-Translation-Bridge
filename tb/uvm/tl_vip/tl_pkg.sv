//==============================================================================
// File: tl_pkg.sv
// Description: UVM Package for TileLink Master Verification IP
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef TL_PKG_SV
`define TL_PKG_SV

package tl_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import tl_axi4_pkg::*;

  `include "tl_seq_item.sv"
  `include "tl_driver.sv"
  `include "tl_monitor.sv"
  `include "tl_sequencer.sv"
  `include "tl_agent.sv"
  `include "tl_sequences.sv"

endpackage : tl_pkg

`endif // TL_PKG_SV
