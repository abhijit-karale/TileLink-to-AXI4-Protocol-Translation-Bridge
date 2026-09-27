//==============================================================================
// File: formal_bridge_top.sv
// Description: Top-level formal verification harness for TileLink-to-AXI4 Bridge
//              incorporating assumptions, assertions, and cover properties.
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef FORMAL_BRIDGE_TOP_SV
`define FORMAL_BRIDGE_TOP_SV

import tl_axi4_pkg::*;

module formal_bridge_top #(
  parameter int ADDR_WIDTH   = 32,
  parameter int DATA_WIDTH   = 64,
  parameter int SOURCE_WIDTH = 4,
  parameter int SINK_WIDTH   = 4,
  parameter int ID_WIDTH     = 4,
  parameter int SIZE_WIDTH   = 4,
  localparam int STRB_WIDTH  = DATA_WIDTH / 8
) (
  input logic clk,
  input logic rst_n
);

  // TileLink Interface Signals
  logic                      tl_a_valid;
  logic                      tl_a_ready;
  tl_a_opcode_e              tl_a_opcode;
  logic [2:0]                tl_a_param;
  logic [SIZE_WIDTH-1:0]     tl_a_size;
  logic [SOURCE_WIDTH-1:0]   tl_a_source;
  logic [ADDR_WIDTH-1:0]     tl_a_address;
  logic [STRB_WIDTH-1:0]     tl_a_mask;
  logic [DATA_WIDTH-1:0]     tl_a_data;
  logic                      tl_a_corrupt;

  logic                      tl_d_valid;
  logic                      tl_d_ready;
  tl_d_opcode_e              tl_d_opcode;
  logic [1:0]                tl_d_param;
  logic [SIZE_WIDTH-1:0]     tl_d_size;
  logic [SOURCE_WIDTH-1:0]   tl_d_source;
  logic [SINK_WIDTH-1:0]     tl_d_sink;
  logic                      tl_d_denied;
  logic [DATA_WIDTH-1:0]     tl_d_data;
  logic                      tl_d_corrupt;

  // AXI4 Interface Signals
  logic [ID_WIDTH-1:0]       m_axi_awid;
  logic [ADDR_WIDTH-1:0]     m_axi_awaddr;
  logic [7:0]                m_axi_awlen;
  logic [2:0]                m_axi_awsize;
  logic [1:0]                m_axi_awburst;
  logic                      m_axi_awlock;
  logic [3:0]                m_axi_awcache;
  logic [2:0]                m_axi_awprot;
  logic [3:0]                m_axi_awqos;
  logic [3:0]                m_axi_awregion;
  logic [0:0]                m_axi_awuser;
  logic                      m_axi_awvalid;
  logic                      m_axi_awready;

  logic [DATA_WIDTH-1:0]     m_axi_wdata;
  logic [STRB_WIDTH-1:0]     m_axi_wstrb;
  logic                      m_axi_wlast;
  logic [0:0]                m_axi_wuser;
  logic                      m_axi_wvalid;
  logic                      m_axi_wready;

  logic [ID_WIDTH-1:0]       m_axi_bid;
  logic [1:0]                m_axi_bresp;
  logic [0:0]                m_axi_buser;
  logic                      m_axi_bvalid;
  logic                      m_axi_bready;

  logic [ID_WIDTH-1:0]       m_axi_arid;
  logic [ADDR_WIDTH-1:0]     m_axi_araddr;
  logic [7:0]                m_axi_arlen;
  logic [2:0]                m_axi_arsize;
  logic [1:0]                m_axi_arburst;
  logic                      m_axi_arlock;
  logic [3:0]                m_axi_arcache;
  logic [2:0]                m_axi_arprot;
  logic [3:0]                m_axi_arqos;
  logic [3:0]                m_axi_arregion;
  logic [0:0]                m_axi_aruser;
  logic                      m_axi_arvalid;
  logic                      m_axi_arready;

  logic [ID_WIDTH-1:0]       m_axi_rid;
  logic [DATA_WIDTH-1:0]     m_axi_rdata;
  logic [1:0]                m_axi_rresp;
  logic                      m_axi_rlast;
  logic [0:0]                m_axi_ruser;
  logic                      m_axi_rvalid;
  logic                      m_axi_rready;

  logic [31:0]               stat_min_latency;
  logic [31:0]               stat_max_latency;
  logic [63:0]               stat_total_latency;
  logic [31:0]               stat_completed_trans;
  logic [ID_WIDTH:0]         stat_active_count;

  // DUT Instantiation
  tl_axi4_bridge_top #(
    .ADDR_WIDTH    (ADDR_WIDTH),
    .DATA_WIDTH    (DATA_WIDTH),
    .SOURCE_WIDTH  (SOURCE_WIDTH),
    .SINK_WIDTH    (SINK_WIDTH),
    .ID_WIDTH      (ID_WIDTH),
    .SIZE_WIDTH    (SIZE_WIDTH),
    .USER_WIDTH    (1),
    .WDATA_FIFO_DP (16)
  ) dut (
    .clk                  (clk),
    .rst_n                (rst_n),
    .tl_a_valid           (tl_a_valid),
    .tl_a_ready           (tl_a_ready),
    .tl_a_opcode          (tl_a_opcode),
    .tl_a_param           (tl_a_param),
    .tl_a_size            (tl_a_size),
    .tl_a_source          (tl_a_source),
    .tl_a_address         (tl_a_address),
    .tl_a_mask            (tl_a_mask),
    .tl_a_data            (tl_a_data),
    .tl_a_corrupt         (tl_a_corrupt),
    .tl_d_valid           (tl_d_valid),
    .tl_d_ready           (tl_d_ready),
    .tl_d_opcode          (tl_d_opcode),
    .tl_d_param           (tl_d_param),
    .tl_d_size            (tl_d_size),
    .tl_d_source          (tl_d_source),
    .tl_d_sink            (tl_d_sink),
    .tl_d_denied          (tl_d_denied),
    .tl_d_data            (tl_d_data),
    .tl_d_corrupt         (tl_d_corrupt),
    .m_axi_awid           (m_axi_awid),
    .m_axi_awaddr         (m_axi_awaddr),
    .m_axi_awlen          (m_axi_awlen),
    .m_axi_awsize         (m_axi_awsize),
    .m_axi_awburst        (m_axi_awburst),
    .m_axi_awlock         (m_axi_awlock),
    .m_axi_awcache        (m_axi_awcache),
    .m_axi_awprot         (m_axi_awprot),
    .m_axi_awqos          (m_axi_awqos),
    .m_axi_awregion       (m_axi_awregion),
    .m_axi_awuser         (m_axi_awuser),
    .m_axi_awvalid        (m_axi_awvalid),
    .m_axi_awready        (m_axi_awready),
    .m_axi_wdata          (m_axi_wdata),
    .m_axi_wstrb          (m_axi_wstrb),
    .m_axi_wlast          (m_axi_wlast),
    .m_axi_wuser          (m_axi_wuser),
    .m_axi_wvalid         (m_axi_wvalid),
    .m_axi_wready         (m_axi_wready),
    .m_axi_bid            (m_axi_bid),
    .m_axi_bresp          (m_axi_bresp),
    .m_axi_buser          (m_axi_buser),
    .m_axi_bvalid         (m_axi_bvalid),
    .m_axi_bready         (m_axi_bready),
    .m_axi_arid           (m_axi_arid),
    .m_axi_araddr         (m_axi_araddr),
    .m_axi_arlen          (m_axi_arlen),
    .m_axi_arsize         (m_axi_arsize),
    .m_axi_arburst        (m_axi_arburst),
    .m_axi_arlock         (m_axi_arlock),
    .m_axi_arcache        (m_axi_arcache),
    .m_axi_arprot         (m_axi_arprot),
    .m_axi_arqos          (m_axi_arqos),
    .m_axi_arregion       (m_axi_arregion),
    .m_axi_aruser         (m_axi_aruser),
    .m_axi_arvalid        (m_axi_arvalid),
    .m_axi_arready        (m_axi_arready),
    .m_axi_rid            (m_axi_rid),
    .m_axi_rdata          (m_axi_rdata),
    .m_axi_rresp          (m_axi_rresp),
    .m_axi_rlast          (m_axi_rlast),
    .m_axi_ruser          (m_axi_ruser),
    .m_axi_rvalid         (m_axi_rvalid),
    .m_axi_rready         (m_axi_rready),
    .stat_min_latency     (stat_min_latency),
    .stat_max_latency     (stat_max_latency),
    .stat_total_latency   (stat_total_latency),
    .stat_completed_trans (stat_completed_trans),
    .stat_active_count    (stat_active_count)
  );

  // Bind SVA Invariants
  bind tl_axi4_bridge_top bridge_sva_invariants #(
    .ADDR_WIDTH   (ADDR_WIDTH),
    .DATA_WIDTH   (DATA_WIDTH),
    .SOURCE_WIDTH (SOURCE_WIDTH),
    .SINK_WIDTH   (SINK_WIDTH),
    .ID_WIDTH     (ID_WIDTH),
    .SIZE_WIDTH   (SIZE_WIDTH)
  ) u_sva (.*);

  //============================================================================
  // Environment Assumptions (Master & Slave Protocol Constraints)
  //============================================================================
  default clocking cb @(posedge clk); endclocking
  default disable iff (!rst_n);

  // Assume valid TileLink opcode
  assume_legal_tl_opcode: assume property (
    tl_a_valid |-> (tl_a_opcode inside {TL_A_PUT_FULL_DATA, TL_A_PUT_PARTIAL_DATA, TL_A_GET})
  );

  // Assume TileLink max size does not exceed 64 bytes (size <= 6)
  assume_legal_tl_size: assume property (
    tl_a_valid |-> (tl_a_size <= 4'd6)
  );

  // Assume TileLink stability
  assume_tl_a_stable: assume property (
    tl_a_valid && !tl_a_ready |=>
      tl_a_valid &&
      $stable(tl_a_opcode) &&
      $stable(tl_a_size) &&
      $stable(tl_a_source) &&
      $stable(tl_a_address)
  );

  // Assume AXI response valid stability
  assume_bvalid_stable: assume property (
    m_axi_bvalid && !m_axi_bready |=> m_axi_bvalid && $stable(m_axi_bid) && $stable(m_axi_bresp)
  );

  assume_rvalid_stable: assume property (
    m_axi_rvalid && !m_axi_rready |=> m_axi_rvalid && $stable(m_axi_rid) && $stable(m_axi_rdata) && $stable(m_axi_rlast)
  );

  //============================================================================
  // Cover Properties for Reachability
  //============================================================================
  // Cover a successful multi-beat write burst
  cover_write_burst_complete: cover property (
    m_axi_wvalid && m_axi_wready && m_axi_wlast
  );

  // Cover a successful multi-beat read burst
  cover_read_burst_complete: cover property (
    m_axi_rvalid && m_axi_rready && m_axi_rlast
  );

  // Cover 4KB boundary segmentation split
  cover_4kb_boundary_split: cover property (
    dut.u_segmenter.crosses_4kb && dut.u_segmenter.req_valid && dut.u_segmenter.req_ready
  );

  // Cover concurrent read and write arbitration
  cover_concurrent_arbitration: cover property (
    m_axi_bvalid && m_axi_rvalid
  );

endmodule : formal_bridge_top

`endif // FORMAL_BRIDGE_TOP_SV
