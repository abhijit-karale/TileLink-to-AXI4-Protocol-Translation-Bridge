//==============================================================================
// File: tl_sequences.sv
// Description: UVM Sequences for TileLink Master Verification
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef TL_SEQUENCES_SV
`define TL_SEQUENCES_SV

// Base Sequence
class tl_base_seq #(
  parameter int ADDR_WIDTH   = 32,
  parameter int DATA_WIDTH   = 64,
  parameter int SOURCE_WIDTH = 4,
  parameter int SIZE_WIDTH   = 4
) extends uvm_sequence #(tl_seq_item#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH));

  typedef tl_seq_item#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH) item_t;

  `uvm_object_param_utils(tl_base_seq#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH))

  function new(string name = "tl_base_seq");
    super.new(name);
  endfunction

endclass : tl_base_seq

// 1. Sanity Sequence: Single 8-byte write and read
class tl_sanity_seq #(
  parameter int ADDR_WIDTH   = 32,
  parameter int DATA_WIDTH   = 64,
  parameter int SOURCE_WIDTH = 4,
  parameter int SIZE_WIDTH   = 4
) extends tl_base_seq#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH);

  `uvm_object_param_utils(tl_sanity_seq#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH))

  function new(string name = "tl_sanity_seq");
    super.new(name);
  endfunction

  virtual task body();
    item_t wr_item, rd_item;

    // 1. Write Item
    `uvm_info(get_type_name(), "Executing Sanity PutFullData Write...", UVM_LOW)
    wr_item = item_t::type_id::create("wr_item");
    start_item(wr_item);
    if (!wr_item.randomize() with {
      opcode  == TL_A_PUT_FULL_DATA;
      address == 32'h0000_1000;
      size    == 4'd3; // 8 bytes (1 beat)
      source  == 4'd1;
    }) `uvm_fatal("RNDFAIL", "Randomization failed for wr_item")
    finish_item(wr_item);

    // 2. Read Item
    `uvm_info(get_type_name(), "Executing Sanity Get Read...", UVM_LOW)
    rd_item = item_t::type_id::create("rd_item");
    start_item(rd_item);
    if (!rd_item.randomize() with {
      opcode  == TL_A_GET;
      address == 32'h0000_1000;
      size    == 4'd3; // 8 bytes
      source  == 4'd2;
    }) `uvm_fatal("RNDFAIL", "Randomization failed for rd_item")
    finish_item(rd_item);
  endtask

endclass : tl_sanity_seq

// 2. Burst Sequence: 64-byte burst writes and reads (8 beats)
class tl_burst_seq #(
  parameter int ADDR_WIDTH   = 32,
  parameter int DATA_WIDTH   = 64,
  parameter int SOURCE_WIDTH = 4,
  parameter int SIZE_WIDTH   = 4
) extends tl_base_seq#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH);

  `uvm_object_param_utils(tl_burst_seq#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH))

  function new(string name = "tl_burst_seq");
    super.new(name);
  endfunction

  virtual task body();
    item_t item;

    // 64-byte Write Burst (8 beats of 64-bit)
    `uvm_info(get_type_name(), "Issuing 64-byte PutFullData Burst...", UVM_LOW)
    item = item_t::type_id::create("burst_wr");
    start_item(item);
    if (!item.randomize() with {
      opcode  == TL_A_PUT_FULL_DATA;
      address == 32'h0000_2000;
      size    == 4'd6; // 64 bytes = 8 beats
      source  == 4'd3;
    }) `uvm_fatal("RNDFAIL", "Burst write randomize failed")
    finish_item(item);

    // 64-byte Read Burst
    `uvm_info(get_type_name(), "Issuing 64-byte Get Burst...", UVM_LOW)
    item = item_t::type_id::create("burst_rd");
    start_item(item);
    if (!item.randomize() with {
      opcode  == TL_A_GET;
      address == 32'h0000_2000;
      size    == 4'd6; // 64 bytes
      source  == 4'd4;
    }) `uvm_fatal("RNDFAIL", "Burst read randomize failed")
    finish_item(item);
  endtask

endclass : tl_burst_seq

// 3. 4KB Straddle Sequence: Intentionally crossing 4KB page boundary
class tl_4kb_straddle_seq #(
  parameter int ADDR_WIDTH   = 32,
  parameter int DATA_WIDTH   = 64,
  parameter int SOURCE_WIDTH = 4,
  parameter int SIZE_WIDTH   = 4
) extends tl_base_seq#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH);

  `uvm_object_param_utils(tl_4kb_straddle_seq#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH))

  function new(string name = "tl_4kb_straddle_seq");
    super.new(name);
  endfunction

  virtual task body();
    item_t item;

    // Address 0x0FE0 is 32 bytes before 0x1000 (4096-byte boundary).
    // A 64-byte burst spans from 0x0FE0 to 0x1020, crossing 4KB!
    `uvm_info(get_type_name(), "Issuing 4KB Boundary Crossing Write...", UVM_LOW)
    item = item_t::type_id::create("straddle_wr");
    start_item(item);
    if (!item.randomize() with {
      opcode  == TL_A_PUT_FULL_DATA;
      address == 32'h0000_0FE0;
      size    == 4'd6; // 64 bytes (splits into 32B + 32B)
      source  == 4'd5;
    }) `uvm_fatal("RNDFAIL", "4KB straddle write randomize failed")
    finish_item(item);

    // Read back spanning 4KB boundary
    `uvm_info(get_type_name(), "Issuing 4KB Boundary Crossing Read...", UVM_LOW)
    item = item_t::type_id::create("straddle_rd");
    start_item(item);
    if (!item.randomize() with {
      opcode  == TL_A_GET;
      address == 32'h0000_0FE0;
      size    == 4'd6;
      source  == 4'd6;
    }) `uvm_fatal("RNDFAIL", "4KB straddle read randomize failed")
    finish_item(item);
  endtask

endclass : tl_4kb_straddle_seq

// 4. Stress Sequence: Random mixed transactions
class tl_stress_seq #(
  parameter int ADDR_WIDTH   = 32,
  parameter int DATA_WIDTH   = 64,
  parameter int SOURCE_WIDTH = 4,
  parameter int SIZE_WIDTH   = 4
) extends tl_base_seq#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH);

  int num_trans = 50;

  `uvm_object_param_utils(tl_stress_seq#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH))

  function new(string name = "tl_stress_seq");
    super.new(name);
  endfunction

  virtual task body();
    item_t item;
    `uvm_info(get_type_name(), $sformatf("Launching stress test with %0d transactions...", num_trans), UVM_LOW)
    for (int i = 0; i < num_trans; i++) begin
      item = item_t::type_id::create($sformatf("stress_item_%0d", i));
      start_item(item);
      if (!item.randomize() with {
        size <= 4'd6;
      }) `uvm_fatal("RNDFAIL", "Stress randomize failed")
      finish_item(item);
    end
  endtask

endclass : tl_stress_seq

`endif // TL_SEQUENCES_SV
