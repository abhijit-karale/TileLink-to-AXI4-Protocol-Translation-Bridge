//==============================================================================
// File: bridge_coverage.sv
// Description: Functional Coverage Model for TileLink-to-AXI4 Bridge
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef BRIDGE_COVERAGE_SV
`define BRIDGE_COVERAGE_SV

class bridge_coverage #(
  parameter int ADDR_WIDTH   = 32,
  parameter int DATA_WIDTH   = 64,
  parameter int SOURCE_WIDTH = 4,
  parameter int ID_WIDTH     = 4,
  parameter int SIZE_WIDTH   = 4
) extends uvm_subscriber #(tl_seq_item#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH));

  typedef tl_seq_item#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH) item_t;

  item_t cur_item;

  // Covergroup for TileLink Requests
  covergroup cg_tl_requests;
    cp_opcode: coverpoint cur_item.opcode {
      bins put_full    = {tl_axi4_pkg::TL_A_PUT_FULL_DATA};
      bins put_partial = {tl_axi4_pkg::TL_A_PUT_PARTIAL_DATA};
      bins get         = {tl_axi4_pkg::TL_A_GET};
    }

    cp_size: coverpoint cur_item.size {
      bins b_1byte  = {0};
      bins b_2byte  = {1};
      bins b_4byte  = {2};
      bins b_8byte  = {3};
      bins b_16byte = {4};
      bins b_32byte = {5};
      bins b_64byte = {6};
    }

    cp_4kb_cross: coverpoint ((cur_item.address[11:0] + (1 << cur_item.size)) > 4096) {
      bins normal_page  = {0};
      bins cross_4kb    = {1};
    }

    cross_op_size: cross cp_opcode, cp_size;
    cross_op_4kb:  cross cp_opcode, cp_4kb_cross;
  endgroup

  `uvm_component_param_utils(bridge_coverage#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, ID_WIDTH, SIZE_WIDTH))

  function new(string name = "bridge_coverage", uvm_component parent = null);
    super.new(name, parent);
    cg_tl_requests = new();
  endfunction

  virtual function void write(item_t t);
    cur_item = t;
    cg_tl_requests.sample();
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COVERAGE", $sformatf("TileLink-to-AXI4 Bridge Functional Coverage: %0.2f%%",
              cg_tl_requests.get_inst_coverage()), UVM_NONE)
  endfunction

endclass : bridge_coverage

`endif // BRIDGE_COVERAGE_SV
