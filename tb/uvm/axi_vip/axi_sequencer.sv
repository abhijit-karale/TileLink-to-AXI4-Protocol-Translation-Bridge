//==============================================================================
// File: axi_sequencer.sv
// Description: UVM Sequencer for AXI4 Slave VIP
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef AXI_SEQUENCER_SV
`define AXI_SEQUENCER_SV

class axi_sequencer #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 64,
  parameter int ID_WIDTH   = 4
) extends uvm_sequencer #(axi_seq_item#(ADDR_WIDTH, DATA_WIDTH, ID_WIDTH));

  `uvm_component_param_utils(axi_sequencer#(ADDR_WIDTH, DATA_WIDTH, ID_WIDTH))

  function new(string name = "axi_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction

endclass : axi_sequencer

`endif // AXI_SEQUENCER_SV
