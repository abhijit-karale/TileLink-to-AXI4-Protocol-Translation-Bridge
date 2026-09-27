//==============================================================================
// File: bridge_base_test.sv
// Description: UVM Base Test establishing environment, timeouts, and report formats
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef BRIDGE_BASE_TEST_SV
`define BRIDGE_BASE_TEST_SV

class bridge_base_test extends uvm_test;

  parameter int ADDR_WIDTH   = 32;
  parameter int DATA_WIDTH   = 64;
  parameter int SOURCE_WIDTH = 4;
  parameter int ID_WIDTH     = 4;
  parameter int SIZE_WIDTH   = 4;

  typedef bridge_env#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, ID_WIDTH, SIZE_WIDTH) env_t;
  env_t env;

  `uvm_component_utils(bridge_base_test)

  function new(string name = "bridge_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = env_t::type_id::create("env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

endclass : bridge_base_test

`endif // BRIDGE_BASE_TEST_SV
