//==============================================================================
// File: bridge_env_pkg.sv
// Description: UVM Package for Bridge Environment
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef BRIDGE_ENV_PKG_SV
`define BRIDGE_ENV_PKG_SV

package bridge_env_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import tl_axi4_pkg::*;
  import tl_pkg::*;
  import axi_pkg::*;

  `include "bridge_scoreboard.sv"
  `include "bridge_coverage.sv"
  `include "bridge_env.sv"

endpackage : bridge_env_pkg

`endif // BRIDGE_ENV_PKG_SV
