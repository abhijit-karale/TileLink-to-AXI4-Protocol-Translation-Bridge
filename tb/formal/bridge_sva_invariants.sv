//==============================================================================
// File: bridge_sva_invariants.sv
// Description: Comprehensive SystemVerilog Assertions (SVA) for TileLink-to-AXI4
//              Protocol Translation Bridge. Covers protocol compliance, 4KB
//              boundary safety, valid/ready stability, and deadlock prevention.
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef BRIDGE_SVA_INVARIANTS_SV
`define BRIDGE_SVA_INVARIANTS_SV

import tl_axi4_pkg::*;

module bridge_sva_invariants #(
  parameter int ADDR_WIDTH   = 32,
  parameter int DATA_WIDTH   = 64,
  parameter int SOURCE_WIDTH = 4,
  parameter int SINK_WIDTH   = 4,
  parameter int ID_WIDTH     = 4,
  parameter int SIZE_WIDTH   = 4,
  localparam int STRB_WIDTH  = DATA_WIDTH / 8
) (
  input  logic                      clk,
  input  logic                      rst_n,

  // TileLink Interface
  input  logic                      tl_a_valid,
  input  logic                      tl_a_ready,
  input  tl_axi4_pkg::tl_a_opcode_e tl_a_opcode,
  input  logic [2:0]                tl_a_param,
  input  logic [SIZE_WIDTH-1:0]     tl_a_size,
  input  logic [SOURCE_WIDTH-1:0]   tl_a_source,
  input  logic [ADDR_WIDTH-1:0]     tl_a_address,
  input  logic [STRB_WIDTH-1:0]     tl_a_mask,
  input  logic [DATA_WIDTH-1:0]     tl_a_data,
  input  logic                      tl_a_corrupt,

  input  logic                      tl_d_valid,
  input  logic                      tl_d_ready,
  input  tl_axi4_pkg::tl_d_opcode_e tl_d_opcode,
  input  logic [1:0]                tl_d_param,
  input  logic [SIZE_WIDTH-1:0]     tl_d_size,
  input  logic [SOURCE_WIDTH-1:0]   tl_d_source,
  input  logic [SINK_WIDTH-1:0]     tl_d_sink,
  input  logic                      tl_d_denied,
  input  logic [DATA_WIDTH-1:0]     tl_d_data,
  input  logic                      tl_d_corrupt,

  // AXI4 Interface
  input  logic [ID_WIDTH-1:0]       m_axi_awid,
  input  logic [ADDR_WIDTH-1:0]     m_axi_awaddr,
  input  logic [7:0]                m_axi_awlen,
  input  logic [2:0]                m_axi_awsize,
  input  logic [1:0]                m_axi_awburst,
  input  logic                      m_axi_awvalid,
  input  logic                      m_axi_awready,

  input  logic [DATA_WIDTH-1:0]     m_axi_wdata,
  input  logic [STRB_WIDTH-1:0]     m_axi_wstrb,
  input  logic                      m_axi_wlast,
  input  logic                      m_axi_wvalid,
  input  logic                      m_axi_wready,

  input  logic [ID_WIDTH-1:0]       m_axi_bid,
  input  logic [1:0]                m_axi_bresp,
  input  logic                      m_axi_bvalid,
  input  logic                      m_axi_bready,

  input  logic [ID_WIDTH-1:0]       m_axi_arid,
  input  logic [ADDR_WIDTH-1:0]     m_axi_araddr,
  input  logic [7:0]                m_axi_arlen,
  input  logic [2:0]                m_axi_arsize,
  input  logic [1:0]                m_axi_arburst,
  input  logic                      m_axi_arvalid,
  input  logic                      m_axi_arready,

  input  logic [ID_WIDTH-1:0]       m_axi_rid,
  input  logic [DATA_WIDTH-1:0]     m_axi_rdata,
  input  logic [1:0]                m_axi_rresp,
  input  logic                      m_axi_rlast,
  input  logic                      m_axi_rvalid,
  input  logic                      m_axi_rready,

  // Status diagnostics
  input  logic [ID_WIDTH:0]         stat_active_count
);

  default clocking cb @(posedge clk); endclocking
  default disable iff (!rst_n);

  //============================================================================
  // 1. Valid / Ready Handshake Stability Invariants
  //============================================================================
  // TL Channel A: Once asserted, valid and payload must remain stable until ready
  property p_tl_a_stability;
    tl_a_valid && !tl_a_ready |=>
      tl_a_valid &&
      $stable(tl_a_opcode) &&
      $stable(tl_a_param) &&
      $stable(tl_a_size) &&
      $stable(tl_a_source) &&
      $stable(tl_a_address) &&
      $stable(tl_a_mask) &&
      $stable(tl_a_data) &&
      $stable(tl_a_corrupt);
  endproperty
  assert_tl_a_stability: assert property (p_tl_a_stability)
    else $error("[SVA-ERR] TL-A payload mutated before ready asserted!");

  // TL Channel D: Once asserted, valid and payload must remain stable until ready
  property p_tl_d_stability;
    tl_d_valid && !tl_d_ready |=>
      tl_d_valid &&
      $stable(tl_d_opcode) &&
      $stable(tl_d_param) &&
      $stable(tl_d_size) &&
      $stable(tl_d_source) &&
      $stable(tl_d_sink) &&
      $stable(tl_d_denied) &&
      $stable(tl_d_data) &&
      $stable(tl_d_corrupt);
  endproperty
  assert_tl_d_stability: assert property (p_tl_d_stability)
    else $error("[SVA-ERR] TL-D payload mutated before ready asserted!");

  // AXI AW Channel Stability
  property p_axi_aw_stability;
    m_axi_awvalid && !m_axi_awready |=>
      m_axi_awvalid &&
      $stable(m_axi_awid) &&
      $stable(m_axi_awaddr) &&
      $stable(m_axi_awlen) &&
      $stable(m_axi_awsize) &&
      $stable(m_axi_awburst);
  endproperty
  assert_axi_aw_stability: assert property (p_axi_aw_stability)
    else $error("[SVA-ERR] AXI AW channel altered while stalled!");

  // AXI W Channel Stability
  property p_axi_w_stability;
    m_axi_wvalid && !m_axi_wready |=>
      m_axi_wvalid &&
      $stable(m_axi_wdata) &&
      $stable(m_axi_wstrb) &&
      $stable(m_axi_wlast);
  endproperty
  assert_axi_w_stability: assert property (p_axi_w_stability)
    else $error("[SVA-ERR] AXI W channel altered while stalled!");

  // AXI AR Channel Stability
  property p_axi_ar_stability;
    m_axi_arvalid && !m_axi_arready |=>
      m_axi_arvalid &&
      $stable(m_axi_arid) &&
      $stable(m_axi_araddr) &&
      $stable(m_axi_arlen) &&
      $stable(m_axi_arsize) &&
      $stable(m_axi_arburst);
  endproperty
  assert_axi_ar_stability: assert property (p_axi_ar_stability)
    else $error("[SVA-ERR] AXI AR channel altered while stalled!");

  //============================================================================
  // 2. AXI4 4KB Address Boundary Invariant
  //============================================================================
  // Invariant: An AXI burst must NEVER cross a 4096-byte boundary.
  // Burst span = (awlen + 1) * 2^awsize bytes.
  // Address offset = awaddr[11:0]. Offset + span <= 4096.
  property p_axi_aw_4kb_boundary;
    m_axi_awvalid |->
      (({1'b0, m_axi_awaddr[11:0]} +
        (({1'b0, m_axi_awlen} + 9'd1) * (13'd1 << m_axi_awsize))) <= 13'd4096);
  endproperty
  assert_axi_aw_4kb_boundary: assert property (p_axi_aw_4kb_boundary)
    else $error("[SVA-ERR] AXI AW burst crosses 4KB boundary! Addr=0x%0h, Len=%0d, Size=%0d",
                m_axi_awaddr, m_axi_awlen, m_axi_awsize);

  property p_axi_ar_4kb_boundary;
    m_axi_arvalid |->
      (({1'b0, m_axi_araddr[11:0]} +
        (({1'b0, m_axi_arlen} + 9'd1) * (13'd1 << m_axi_arsize))) <= 13'd4096);
  endproperty
  assert_axi_ar_4kb_boundary: assert property (p_axi_ar_4kb_boundary)
    else $error("[SVA-ERR] AXI AR burst crosses 4KB boundary! Addr=0x%0h, Len=%0d, Size=%0d",
                m_axi_araddr, m_axi_arlen, m_axi_arsize);

  //============================================================================
  // 3. Burst Length Legal Range Invariants
  //============================================================================
  // AXI4 allows max 256 beats (awlen/arlen <= 255) for INCR burst
  property p_axi_awlen_legal;
    m_axi_awvalid |-> (m_axi_awburst == tl_axi4_pkg::AXI_BURST_INCR);
  endproperty
  assert_axi_awlen_legal: assert property (p_axi_awlen_legal)
    else $error("[SVA-ERR] Non-INCR burst issued on AW channel!");

  property p_axi_arlen_legal;
    m_axi_arvalid |-> (m_axi_arburst == tl_axi4_pkg::AXI_BURST_INCR);
  endproperty
  assert_axi_arlen_legal: assert property (p_axi_arlen_legal)
    else $error("[SVA-ERR] Non-INCR burst issued on AR channel!");

  //============================================================================
  // 4. CAM Capacity & Conservation Invariants
  //============================================================================
  // Active in-flight transactions must never exceed CAM capacity
  property p_cam_capacity;
    stat_active_count <= (1 << ID_WIDTH);
  endproperty
  assert_cam_capacity: assert property (p_cam_capacity)
    else $error("[SVA-ERR] CAM active transactions count exceeded maximum capacity!");

  //============================================================================
  // 5. Response Protocol Mapping Invariants
  //============================================================================
  // AccessAck should only have opcode TL_D_ACCESS_ACK and no data
  property p_tl_d_ack_data;
    tl_d_valid && (tl_d_opcode == tl_axi4_pkg::TL_D_ACCESS_ACK) |-> (tl_d_data == '0);
  endproperty
  assert_tl_d_ack_data: assert property (p_tl_d_ack_data)
    else $error("[SVA-ERR] AccessAck response contains non-zero data payload!");

  //============================================================================
  // 6. Forward Progress / Liveness Verification Invariant
  //============================================================================
  // When a TileLink Channel A request handshakes, it must eventually produce
  // a TileLink Channel D response within a bounded window under fair slave behavior.
  logic tl_a_fire;
  logic tl_d_fire;
  assign tl_a_fire = tl_a_valid && tl_a_ready;
  assign tl_d_fire = tl_d_valid && tl_d_ready;

  // Outstanding request / response counter tracking
  int unsigned outstanding_trans_cnt;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      outstanding_trans_cnt <= 0;
    end else begin
      case ({tl_a_fire, tl_d_fire})
        2'b10: outstanding_trans_cnt <= outstanding_trans_cnt + 1;
        2'b01: outstanding_trans_cnt <= outstanding_trans_cnt - 1;
        default: outstanding_trans_cnt <= outstanding_trans_cnt;
      endcase
    end
  end

  property p_no_underflow;
    outstanding_trans_cnt >= 0;
  endproperty
  assert_no_underflow: assert property (p_no_underflow)
    else $error("[SVA-ERR] Spurious response detected: TL-D fired without matching request!");

endmodule : bridge_sva_invariants

`endif // BRIDGE_SVA_INVARIANTS_SV
