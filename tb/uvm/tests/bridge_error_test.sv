//==============================================================================
// File: bridge_error_test.sv
// Description: UVM Error Injection Test verifying AXI SLVERR/DECERR mapping
//              to TileLink d_denied and d_corrupt indicators.
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef BRIDGE_ERROR_TEST_SV
`define BRIDGE_ERROR_TEST_SV

class bridge_error_test extends bridge_base_test;

  `uvm_component_utils(bridge_error_test)

  function new(string name = "bridge_error_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    tl_sanity_seq#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH) seq;

    phase.raise_objection(this);
    `uvm_info(get_type_name(), "===== Starting Bridge Error Response Test =====", UVM_LOW)

    // Enable error injection in AXI slave driver
    env.axi_slv_agent.driver.inject_error = 1'b1;
    env.axi_slv_agent.driver.error_resp   = tl_axi4_pkg::AXI_RESP_SLVERR;

    seq = tl_sanity_seq#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH)::type_id::create("seq");
    seq.start(env.tl_mst_agent.sequencer);

    #200ns;
    `uvm_info(get_type_name(), "===== Finished Bridge Error Response Test =====", UVM_LOW)
    phase.drop_objection(this);
  endtask

endclass : bridge_error_test

`endif // BRIDGE_ERROR_TEST_SV
