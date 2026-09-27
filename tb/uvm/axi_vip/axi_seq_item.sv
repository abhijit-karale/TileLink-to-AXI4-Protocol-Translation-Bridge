//==============================================================================
// File: axi_seq_item.sv
// Description: UVM Sequence Item for AXI4 Transactions
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef AXI_SEQ_ITEM_SV
`define AXI_SEQ_ITEM_SV

class axi_seq_item #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 64,
  parameter int ID_WIDTH   = 4,
  localparam int STRB_WIDTH = DATA_WIDTH / 8
) extends uvm_sequence_item;

  typedef enum logic { AXI_TRANS_READ = 1'b0, AXI_TRANS_WRITE = 1'b1 } trans_type_e;

  // Transaction attributes
  rand trans_type_e        trans_type;
  rand logic [ID_WIDTH-1:0]   id;
  rand logic [ADDR_WIDTH-1:0] addr;
  rand logic [7:0]            len;
  rand logic [2:0]            size;
  rand logic [1:0]            burst;

  // Write Data Beats
  rand logic [DATA_WIDTH-1:0] wdata[];
  rand logic [STRB_WIDTH-1:0] wstrb[];

  // Write Response
  rand logic [1:0]            bresp;

  // Read Data Beats & Responses
  rand logic [DATA_WIDTH-1:0] rdata[];
  rand logic [1:0]            rresp[];

  // Timing
  int                         delay_cycles;

  `uvm_object_param_utils_begin(axi_seq_item#(ADDR_WIDTH, DATA_WIDTH, ID_WIDTH))
    `uvm_field_enum(trans_type_e, trans_type, UVM_ALL_ON)
    `uvm_field_int(id, UVM_ALL_ON)
    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_int(len, UVM_ALL_ON)
    `uvm_field_int(size, UVM_ALL_ON)
    `uvm_field_int(burst, UVM_ALL_ON)
    `uvm_field_array_int(wdata, UVM_ALL_ON)
    `uvm_field_array_int(wstrb, UVM_ALL_ON)
    `uvm_field_int(bresp, UVM_ALL_ON)
    `uvm_field_array_int(rdata, UVM_ALL_ON)
    `uvm_field_array_int(rresp, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "axi_seq_item");
    super.new(name);
    bresp = 2'b00; // OKAY by default
  endfunction

endclass : axi_seq_item

`endif // AXI_SEQ_ITEM_SV
