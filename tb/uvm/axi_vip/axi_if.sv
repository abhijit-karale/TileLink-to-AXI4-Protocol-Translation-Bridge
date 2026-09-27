//==============================================================================
// File: axi_if.sv
// Description: SystemVerilog Interface for AXI4 Full 5-Channel Protocol
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef AXI_IF_SV
`define AXI_IF_SV

import tl_axi4_pkg::*;

interface axi_if #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 64,
  parameter int ID_WIDTH   = 4,
  parameter int USER_WIDTH = 1,
  localparam int STRB_WIDTH = DATA_WIDTH / 8
) (
  input logic clk,
  input logic rst_n
);

  // AW Channel
  logic [ID_WIDTH-1:0]   awid;
  logic [ADDR_WIDTH-1:0] awaddr;
  logic [7:0]            awlen;
  logic [2:0]            awsize;
  logic [1:0]            awburst;
  logic                  awlock;
  logic [3:0]            awcache;
  logic [2:0]            awprot;
  logic [3:0]            awqos;
  logic [3:0]            awregion;
  logic [USER_WIDTH-1:0] awuser;
  logic                  awvalid;
  logic                  awready;

  // W Channel
  logic [DATA_WIDTH-1:0] wdata;
  logic [STRB_WIDTH-1:0] wstrb;
  logic                  wlast;
  logic [USER_WIDTH-1:0] wuser;
  logic                  wvalid;
  logic                  wready;

  // B Channel
  logic [ID_WIDTH-1:0]   bid;
  logic [1:0]            bresp;
  logic [USER_WIDTH-1:0] buser;
  logic                  bvalid;
  logic                  bready;

  // AR Channel
  logic [ID_WIDTH-1:0]   arid;
  logic [ADDR_WIDTH-1:0] araddr;
  logic [7:0]            arlen;
  logic [2:0]            arsize;
  logic [1:0]            arburst;
  logic                  arlock;
  logic [3:0]            arcache;
  logic [2:0]            arprot;
  logic [3:0]            arqos;
  logic [3:0]            arregion;
  logic [USER_WIDTH-1:0] aruser;
  logic                  arvalid;
  logic                  arready;

  // R Channel
  logic [ID_WIDTH-1:0]   rid;
  logic [DATA_WIDTH-1:0] rdata;
  logic [1:0]            rresp;
  logic                  rlast;
  logic [USER_WIDTH-1:0] ruser;
  logic                  rvalid;
  logic                  rready;

  // Driver Clocking Block (Slave perspective)
  clocking drv_cb @(posedge clk);
    default input #1step output #100ps;
    input  awid;
    input  awaddr;
    input  awlen;
    input  awsize;
    input  awburst;
    input  awlock;
    input  awcache;
    input  awprot;
    input  awqos;
    input  awregion;
    input  awuser;
    input  awvalid;
    output awready;

    input  wdata;
    input  wstrb;
    input  wlast;
    input  wuser;
    input  wvalid;
    output wready;

    output bid;
    output bresp;
    output buser;
    output bvalid;
    input  bready;

    input  arid;
    input  araddr;
    input  arlen;
    input  arsize;
    input  arburst;
    input  arlock;
    input  arcache;
    input  arprot;
    input  arqos;
    input  arregion;
    input  aruser;
    input  arvalid;
    output arready;

    output rid;
    output rdata;
    output rresp;
    output rlast;
    output ruser;
    output rvalid;
    input  rready;
  endclocking

  // Monitor Clocking Block
  clocking mon_cb @(posedge clk);
    default input #1step;
    input awid, awaddr, awlen, awsize, awburst, awvalid, awready;
    input wdata, wstrb, wlast, wvalid, wready;
    input bid, bresp, bvalid, bready;
    input arid, araddr, arlen, arsize, arburst, arvalid, arready;
    input rid, rdata, rresp, rlast, rvalid, rready;
  endclocking

  modport slave (
    clocking drv_cb,
    input clk,
    input rst_n
  );

  modport monitor (
    clocking mon_cb,
    input clk,
    input rst_n
  );

endinterface : axi_if

`endif // AXI_IF_SV
