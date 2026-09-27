//==============================================================================
// File: bridge_burst_test.sv
// Description: UVM Burst & 4KB Segmentation Test verifying multi-beat bursts
//              and split handling across 4KB address boundaries.
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef BRIDGE_BURST_TEST_SV
`define BRIDGE_BURST_TEST_SV

class bridge_burst_test extends bridge_base_test;

  `uvm_component_utils(bridge_burst_test)

  function new(string name = "bridge_burst_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    tl_burst_seq#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH)         burst_seq;
    tl_4kb_straddle_seq#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH)  straddle_seq;

    phase.raise_objection(this);
    `uvm_info(get_type_name(), "===== Starting Bridge Burst & 4KB Segmentation Test =====", UVM_LOW)

    // 1. Run standard aligned bursts
    burst_seq = tl_burst_seq#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH)::type_id::create("burst_seq");
    burst_seq.start(env.tl_mst_agent.sequencer);

    #100ns;

    // 2. Run 4KB boundary straddle bursts (triggers hardware burst segmentation)
    straddle_seq = tl_4kb_straddle_seq#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH)::type_id::create("straddle_seq");
    straddle_seq.start(env.tl_mst_agent.sequencer);

    #300ns;
    `uvm_info(get_type_name(), "===== Finished Bridge Burst & 4KB Segmentation Test =====", UVM_LOW)
    phase.drop_objection(this);
  endtask

endclass : bridge_burst_test

`endif // BRIDGE_BURST_TEST_SV
