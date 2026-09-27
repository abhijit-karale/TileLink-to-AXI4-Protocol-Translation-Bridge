//==============================================================================
// File: tl_sequencer.sv
// Description: UVM Sequencer for TileLink Master Agent
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef TL_SEQUENCER_SV
`define TL_SEQUENCER_SV

class tl_sequencer #(
  parameter int ADDR_WIDTH   = 32,
  parameter int DATA_WIDTH   = 64,
  parameter int SOURCE_WIDTH = 4,
  parameter int SIZE_WIDTH   = 4
) extends uvm_sequencer #(tl_seq_item#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH));

  `uvm_component_param_utils(tl_sequencer#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH))

  function new(string name = "tl_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction

endclass : tl_sequencer

`endif // TL_SEQUENCER_SV
