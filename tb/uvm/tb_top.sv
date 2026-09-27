//==============================================================================
// File: tb_top.sv
// Description: Top-Level UVM 1.2 Testbench for TileLink-to-AXI4 Protocol Bridge
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`timescale 1ns/1ps

`include "uvm_macros.svh"

module tb_top;

  import uvm_pkg::*;
  import tl_axi4_pkg::*;
  import tl_pkg::*;
  import axi_pkg::*;
  import bridge_env_pkg::*;
  import bridge_tests_pkg::*;

  // Parameters
  localparam int ADDR_WIDTH      = 32;
  localparam int DATA_WIDTH      = 64;
  localparam int SOURCE_WIDTH    = 4;
  localparam int SINK_WIDTH      = 4;
  localparam int ID_WIDTH        = 4;
  localparam int SIZE_WIDTH      = 4;
  localparam int USER_WIDTH      = 1;
  localparam int WDATA_FIFO_DP   = 16;
  localparam int STRB_WIDTH      = DATA_WIDTH / 8;

  // Clock & Reset (200 MHz -> 5.0ns period)
  logic clk;
  logic rst_n;

  initial begin
    clk = 1'b0;
    forever #2.5ns clk = ~clk;
  end

  initial begin
    rst_n = 1'b0;
    #25ns;
    @(posedge clk);
    rst_n = 1'b1;
  end

  // Interfaces
  tl_if #(
    .ADDR_WIDTH   (ADDR_WIDTH),
    .DATA_WIDTH   (DATA_WIDTH),
    .SOURCE_WIDTH (SOURCE_WIDTH),
    .SINK_WIDTH   (SINK_WIDTH),
    .SIZE_WIDTH   (SIZE_WIDTH)
  ) tl_vif (
    .clk   (clk),
    .rst_n (rst_n)
  );

  axi_if #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .ID_WIDTH   (ID_WIDTH),
    .USER_WIDTH (USER_WIDTH)
  ) axi_vif (
    .clk   (clk),
    .rst_n (rst_n)
  );

  // Diagnostics signals
  logic [31:0]       stat_min_latency;
  logic [31:0]       stat_max_latency;
  logic [63:0]       stat_total_latency;
  logic [31:0]       stat_completed_trans;
  logic [ID_WIDTH:0] stat_active_count;

  // DUT Instantiation
  tl_axi4_bridge_top #(
    .ADDR_WIDTH    (ADDR_WIDTH),
    .DATA_WIDTH    (DATA_WIDTH),
    .SOURCE_WIDTH  (SOURCE_WIDTH),
    .SINK_WIDTH    (SINK_WIDTH),
    .ID_WIDTH      (ID_WIDTH),
    .SIZE_WIDTH    (SIZE_WIDTH),
    .USER_WIDTH    (USER_WIDTH),
    .WDATA_FIFO_DP (WDATA_FIFO_DP)
  ) dut (
    .clk                  (clk),
    .rst_n                (rst_n),
    .tl_a_valid           (tl_vif.a_valid),
    .tl_a_ready           (tl_vif.a_ready),
    .tl_a_opcode          (tl_vif.a_opcode),
    .tl_a_param           (tl_vif.a_param),
    .tl_a_size            (tl_vif.a_size),
    .tl_a_source          (tl_vif.a_source),
    .tl_a_address         (tl_vif.a_address),
    .tl_a_mask            (tl_vif.a_mask),
    .tl_a_data            (tl_vif.a_data),
    .tl_a_corrupt         (tl_vif.a_corrupt),
    .tl_d_valid           (tl_vif.d_valid),
    .tl_d_ready           (tl_vif.d_ready),
    .tl_d_opcode          (tl_vif.d_opcode),
    .tl_d_param           (tl_vif.d_param),
    .tl_d_size            (tl_vif.d_size),
    .tl_d_source          (tl_vif.d_source),
    .tl_d_sink            (tl_vif.d_sink),
    .tl_d_denied          (tl_vif.d_denied),
    .tl_d_data            (tl_vif.d_data),
    .tl_d_corrupt         (tl_vif.d_corrupt),
    .m_axi_awid           (axi_vif.awid),
    .m_axi_awaddr         (axi_vif.awaddr),
    .m_axi_awlen          (axi_vif.awlen),
    .m_axi_awsize         (axi_vif.awsize),
    .m_axi_awburst        (axi_vif.awburst),
    .m_axi_awlock         (axi_vif.awlock),
    .m_axi_awcache        (axi_vif.awcache),
    .m_axi_awprot         (axi_vif.awprot),
    .m_axi_awqos          (axi_vif.awqos),
    .m_axi_awregion       (axi_vif.awregion),
    .m_axi_awuser         (axi_vif.awuser),
    .m_axi_awvalid        (axi_vif.awvalid),
    .m_axi_awready        (axi_vif.awready),
    .m_axi_wdata          (axi_vif.wdata),
    .m_axi_wstrb          (axi_vif.wstrb),
    .m_axi_wlast          (axi_vif.wlast),
    .m_axi_wuser          (axi_vif.wuser),
    .m_axi_wvalid         (axi_vif.wvalid),
    .m_axi_wready         (axi_vif.wready),
    .m_axi_bid            (axi_vif.bid),
    .m_axi_bresp          (axi_vif.bresp),
    .m_axi_buser          (axi_vif.buser),
    .m_axi_bvalid         (axi_vif.bvalid),
    .m_axi_bready         (axi_vif.bready),
    .m_axi_arid           (axi_vif.arid),
    .m_axi_araddr         (axi_vif.araddr),
    .m_axi_arlen          (axi_vif.arlen),
    .m_axi_arsize         (axi_vif.arsize),
    .m_axi_arburst        (axi_vif.arburst),
    .m_axi_arlock         (axi_vif.arlock),
    .m_axi_arcache        (axi_vif.arcache),
    .m_axi_arprot         (axi_vif.arprot),
    .m_axi_arqos          (axi_vif.arqos),
    .m_axi_arregion       (axi_vif.arregion),
    .m_axi_aruser         (axi_vif.aruser),
    .m_axi_arvalid        (axi_vif.arvalid),
    .m_axi_arready        (axi_vif.arready),
    .m_axi_rid            (axi_vif.rid),
    .m_axi_rdata          (axi_vif.rdata),
    .m_axi_rresp          (axi_vif.rresp),
    .m_axi_rlast          (axi_vif.rlast),
    .m_axi_ruser          (axi_vif.ruser),
    .m_axi_rvalid         (axi_vif.rvalid),
    .m_axi_rready         (axi_vif.rready),
    .stat_min_latency     (stat_min_latency),
    .stat_max_latency     (stat_max_latency),
    .stat_total_latency   (stat_total_latency),
    .stat_completed_trans (stat_completed_trans),
    .stat_active_count    (stat_active_count)
  );

  // Bind SVA Bridge Invariants
  bind tl_axi4_bridge_top bridge_sva_invariants #(
    .ADDR_WIDTH   (ADDR_WIDTH),
    .DATA_WIDTH   (DATA_WIDTH),
    .SOURCE_WIDTH (SOURCE_WIDTH),
    .SINK_WIDTH   (SINK_WIDTH),
    .ID_WIDTH     (ID_WIDTH),
    .SIZE_WIDTH   (SIZE_WIDTH)
  ) u_sva (.*);

  // Testbench Setup
  initial begin
    // Store interfaces into uvm_config_db
    uvm_config_db#(virtual tl_if#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SINK_WIDTH, SIZE_WIDTH))::set(
      null, "uvm_test_top.env.tl_mst_agent*", "vif", tl_vif
    );
    uvm_config_db#(virtual axi_if#(ADDR_WIDTH, DATA_WIDTH, ID_WIDTH))::set(
      null, "uvm_test_top.env.axi_slv_agent*", "vif", axi_vif
    );

    // Optional VCD dump
    if ($test$plusargs("DUMP_VCD")) begin
      $dumpfile("waveform.vcd");
      $dumpvars(0, tb_top);
    end

    run_test();
  end

endmodule : tb_top
