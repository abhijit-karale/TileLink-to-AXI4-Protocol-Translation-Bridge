//==============================================================================
// File: bridge_tests_pkg.sv
// Description: UVM Package for Bridge Verification Tests
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef BRIDGE_TESTS_PKG_SV
`define BRIDGE_TESTS_PKG_SV

package bridge_tests_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import tl_axi4_pkg::*;
  import tl_pkg::*;
  import axi_pkg::*;
  import bridge_env_pkg::*;

  `include "bridge_base_test.sv"
  `include "bridge_sanity_test.sv"
  `include "bridge_burst_test.sv"
  `include "bridge_stress_test.sv"
  `include "bridge_error_test.sv"

endpackage : bridge_tests_pkg

`endif // BRIDGE_TESTS_PKG_SV
