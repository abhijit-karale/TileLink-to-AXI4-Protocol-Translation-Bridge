//==============================================================================
// File: bridge_stress_test.sv
// Description: UVM Stress Test running high concurrency randomized mixed traffic
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef BRIDGE_STRESS_TEST_SV
`define BRIDGE_STRESS_TEST_SV

class bridge_stress_test extends bridge_base_test;

  `uvm_component_utils(bridge_stress_test)

  function new(string name = "bridge_stress_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    tl_stress_seq#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH) stress_seq;

    phase.raise_objection(this);
    `uvm_info(get_type_name(), "===== Starting Bridge High-Concurrency Stress Test =====", UVM_LOW)

    stress_seq = tl_stress_seq#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH)::type_id::create("stress_seq");
    stress_seq.num_trans = 40;
    stress_seq.start(env.tl_mst_agent.sequencer);

    #500ns;
    `uvm_info(get_type_name(), "===== Finished Bridge High-Concurrency Stress Test =====", UVM_LOW)
    phase.drop_objection(this);
  endtask

endclass : bridge_stress_test

`endif // BRIDGE_STRESS_TEST_SV
