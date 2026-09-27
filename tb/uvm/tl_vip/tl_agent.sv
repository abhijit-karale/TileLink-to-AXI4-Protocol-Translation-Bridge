//==============================================================================
// File: tl_agent.sv
// Description: UVM Agent for TileLink Master
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef TL_AGENT_SV
`define TL_AGENT_SV

class tl_agent #(
  parameter int ADDR_WIDTH   = 32,
  parameter int DATA_WIDTH   = 64,
  parameter int SOURCE_WIDTH = 4,
  parameter int SIZE_WIDTH   = 4
) extends uvm_agent;

  typedef tl_driver#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH)    drv_t;
  typedef tl_monitor#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH)   mon_t;
  typedef tl_sequencer#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH) sqr_t;

  drv_t driver;
  mon_t monitor;
  sqr_t sequencer;

  `uvm_component_param_utils(tl_agent#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH))

  function new(string name = "tl_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = mon_t::type_id::create("monitor", this);
    if (get_is_active() == UVM_ACTIVE) begin
      driver    = drv_t::type_id::create("driver", this);
      sequencer = sqr_t::type_id::create("sequencer", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction

endclass : tl_agent

`endif // TL_AGENT_SV
