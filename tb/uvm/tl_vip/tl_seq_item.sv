//==============================================================================
// File: tl_seq_item.sv
// Description: UVM Sequence Item for TileLink-UH Transactions
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef TL_SEQ_ITEM_SV
`define TL_SEQ_ITEM_SV

class tl_seq_item #(
  parameter int ADDR_WIDTH   = 32,
  parameter int DATA_WIDTH   = 64,
  parameter int SOURCE_WIDTH = 4,
  parameter int SIZE_WIDTH   = 4,
  localparam int STRB_WIDTH  = DATA_WIDTH / 8
) extends uvm_sequence_item;

  // Request Fields (Channel A)
  rand tl_a_opcode_e              opcode;
  rand logic [2:0]                param;
  rand logic [SIZE_WIDTH-1:0]     size;      // log2(total bytes)
  rand logic [SOURCE_WIDTH-1:0]   source;
  rand logic [ADDR_WIDTH-1:0]     address;
  rand logic [STRB_WIDTH-1:0]     mask[];
  rand logic [DATA_WIDTH-1:0]     data[];
  rand logic                      corrupt;

  // Response Fields (Channel D)
  tl_d_opcode_e                   d_opcode;
  logic [1:0]                     d_param;
  logic [SIZE_WIDTH-1:0]          d_size;
  logic [SOURCE_WIDTH-1:0]        d_source;
  logic                           d_denied;
  logic [DATA_WIDTH-1:0]          d_data[];
  logic                           d_corrupt;

  // Latency measurement
  time                            start_time;
  time                            end_time;
  int                             latency_cycles;

  `uvm_object_param_utils_begin(tl_seq_item#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH))
    `uvm_field_enum(tl_a_opcode_e, opcode, UVM_ALL_ON)
    `uvm_field_int(param, UVM_ALL_ON)
    `uvm_field_int(size, UVM_ALL_ON)
    `uvm_field_int(source, UVM_ALL_ON)
    `uvm_field_int(address, UVM_ALL_ON)
    `uvm_field_array_int(mask, UVM_ALL_ON)
    `uvm_field_array_int(data, UVM_ALL_ON)
    `uvm_field_int(corrupt, UVM_ALL_ON)
    `uvm_field_enum(tl_d_opcode_e, d_opcode, UVM_ALL_ON)
    `uvm_field_int(d_param, UVM_ALL_ON)
    `uvm_field_int(d_size, UVM_ALL_ON)
    `uvm_field_int(d_source, UVM_ALL_ON)
    `uvm_field_int(d_denied, UVM_ALL_ON)
    `uvm_field_array_int(d_data, UVM_ALL_ON)
    `uvm_field_int(d_corrupt, UVM_ALL_ON)
  `uvm_object_utils_end

  // Constraints
  constraint c_legal_opcode {
    opcode inside {TL_A_PUT_FULL_DATA, TL_A_PUT_PARTIAL_DATA, TL_A_GET};
  }

  constraint c_legal_size {
    size <= 4'd6; // Up to 64 bytes
  }

  constraint c_addr_align {
    // Naturally aligned to transfer size if size <= bus_bytes
    if (size <= 3) {
      address[1:0] == 2'b00;
    }
  }

  function new(string name = "tl_seq_item");
    super.new(name);
  endfunction

  function void post_randomize();
    int total_bytes;
    int beats;
    int bus_bytes;

    bus_bytes   = DATA_WIDTH / 8;
    total_bytes = 1 << size;
    beats       = (total_bytes <= bus_bytes) ? 1 : (total_bytes / bus_bytes);

    if (opcode != TL_A_GET) begin
      data = new[beats];
      mask = new[beats];
      for (int i = 0; i < beats; i++) begin
        if (!this.randomize(data[i])) data[i] = $urandom();
        if (opcode == TL_A_PUT_FULL_DATA) begin
          mask[i] = '1;
        end else begin
          if (!this.randomize(mask[i])) mask[i] = '1;
          if (mask[i] == '0) mask[i] = '1;
        end
      end
    end else begin
      data = new[0];
      mask = new[0];
    end
  endfunction

endclass : tl_seq_item

`endif // TL_SEQ_ITEM_SV
