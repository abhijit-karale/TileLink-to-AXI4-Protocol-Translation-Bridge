//==============================================================================
// File: bridge_sanity_test.sv
// Description: UVM Sanity Test running single write and single read operations
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef BRIDGE_SANITY_TEST_SV
`define BRIDGE_SANITY_TEST_SV

class bridge_sanity_test extends bridge_base_test;

  `uvm_component_utils(bridge_sanity_test)

  function new(string name = "bridge_sanity_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    tl_sanity_seq#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH) seq;
    phase.raise_objection(this);

    `uvm_info(get_type_name(), "===== Starting Bridge Sanity Test =====", UVM_LOW)
    seq = tl_sanity_seq#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH)::type_id::create("seq");
    seq.start(env.tl_mst_agent.sequencer);

    #200ns;
    `uvm_info(get_type_name(), "===== Finished Bridge Sanity Test =====", UVM_LOW)
    phase.drop_objection(this);
  endtask

endclass : bridge_sanity_test

`endif // BRIDGE_SANITY_TEST_SV
