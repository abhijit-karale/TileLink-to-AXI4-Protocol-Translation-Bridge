//==============================================================================
// File: bridge_env.sv
// Description: UVM Environment instantiating TL Master VIP, AXI4 Slave VIP,
//              Scoreboard, and Coverage Model.
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef BRIDGE_ENV_SV
`define BRIDGE_ENV_SV

class bridge_env #(
  parameter int ADDR_WIDTH   = 32,
  parameter int DATA_WIDTH   = 64,
  parameter int SOURCE_WIDTH = 4,
  parameter int ID_WIDTH     = 4,
  parameter int SIZE_WIDTH   = 4
) extends uvm_env;

  typedef tl_agent#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH)                 tl_agent_t;
  typedef axi_agent#(ADDR_WIDTH, DATA_WIDTH, ID_WIDTH)                                axi_agent_t;
  typedef bridge_scoreboard#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, ID_WIDTH, SIZE_WIDTH) scb_t;
  typedef bridge_coverage#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, ID_WIDTH, SIZE_WIDTH)   cov_t;

  tl_agent_t  tl_mst_agent;
  axi_agent_t axi_slv_agent;
  scb_t       scoreboard;
  cov_t       coverage;

  `uvm_component_param_utils(bridge_env#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, ID_WIDTH, SIZE_WIDTH))

  function new(string name = "bridge_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    tl_mst_agent  = tl_agent_t::type_id::create("tl_mst_agent", this);
    axi_slv_agent = axi_agent_t::type_id::create("axi_slv_agent", this);
    scoreboard    = scb_t::type_id::create("scoreboard", this);
    coverage      = cov_t::type_id::create("coverage", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Connect TileLink analysis ports
    tl_mst_agent.monitor.a_ap.connect(scoreboard.tl_a_export);
    tl_mst_agent.monitor.a_ap.connect(coverage.analysis_export);
    tl_mst_agent.monitor.d_ap.connect(scoreboard.tl_d_export);

    // Connect AXI analysis ports
    axi_slv_agent.monitor.wr_ap.connect(scoreboard.axi_wr_export);
    axi_slv_agent.monitor.rd_ap.connect(scoreboard.axi_rd_export);
  endfunction

endclass : bridge_env

`endif // BRIDGE_ENV_SV
