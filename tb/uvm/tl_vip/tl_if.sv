//==============================================================================
// File: tl_if.sv
// Description: SystemVerilog Interface for TileLink-UH (Channels A and D)
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef TL_IF_SV
`define TL_IF_SV

import tl_axi4_pkg::*;

interface tl_if #(
  parameter int ADDR_WIDTH   = 32,
  parameter int DATA_WIDTH   = 64,
  parameter int SOURCE_WIDTH = 4,
  parameter int SINK_WIDTH   = 4,
  parameter int SIZE_WIDTH   = 4,
  localparam int STRB_WIDTH  = DATA_WIDTH / 8
) (
  input logic clk,
  input logic rst_n
);

  // Channel A (Master -> Slave Request)
  logic                      a_valid;
  logic                      a_ready;
  tl_a_opcode_e              a_opcode;
  logic [2:0]                a_param;
  logic [SIZE_WIDTH-1:0]     a_size;
  logic [SOURCE_WIDTH-1:0]   a_source;
  logic [ADDR_WIDTH-1:0]     a_address;
  logic [STRB_WIDTH-1:0]     a_mask;
  logic [DATA_WIDTH-1:0]     a_data;
  logic                      a_corrupt;

  // Channel D (Slave -> Master Response)
  logic                      d_valid;
  logic                      d_ready;
  tl_d_opcode_e              d_opcode;
  logic [1:0]                d_param;
  logic [SIZE_WIDTH-1:0]     d_size;
  logic [SOURCE_WIDTH-1:0]   d_source;
  logic [SINK_WIDTH-1:0]     d_sink;
  logic                      d_denied;
  logic [DATA_WIDTH-1:0]     d_data;
  logic                      d_corrupt;

  // Driver Clocking Block
  clocking drv_cb @(posedge clk);
    default input #1step output #100ps;
    output a_valid;
    input  a_ready;
    output a_opcode;
    output a_param;
    output a_size;
    output a_source;
    output a_address;
    output a_mask;
    output a_data;
    output a_corrupt;

    input  d_valid;
    output d_ready;
    input  d_opcode;
    input  d_param;
    input  d_size;
    input  d_source;
    input  d_sink;
    input  d_denied;
    input  d_data;
    input  d_corrupt;
  endclocking

  // Monitor Clocking Block
  clocking mon_cb @(posedge clk);
    default input #1step;
    input a_valid;
    input a_ready;
    input a_opcode;
    input a_param;
    input a_size;
    input a_source;
    input a_address;
    input a_mask;
    input a_data;
    input a_corrupt;

    input d_valid;
    input d_ready;
    input d_opcode;
    input d_param;
    input d_size;
    input d_source;
    input d_sink;
    input d_denied;
    input d_data;
    input d_corrupt;
  endclocking

  modport master (
    clocking drv_cb,
    input clk,
    input rst_n
  );

  modport monitor (
    clocking mon_cb,
    input clk,
    input rst_n
  );

endinterface : tl_if

`endif // TL_IF_SV
