//==============================================================================
// File: tl_d_transmitter.sv
// Description: TileLink Channel D Transmitter with zero-bubble response
//              arbitration (R data bursts vs B write acks) and output skid buffer.
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef TL_D_TRANSMITTER_SV
`define TL_D_TRANSMITTER_SV

import tl_axi4_pkg::*;

module tl_d_transmitter #(
  parameter int DATA_WIDTH   = 64,
  parameter int ID_WIDTH     = 4,
  parameter int SOURCE_WIDTH = 4,
  parameter int SINK_WIDTH   = 4,
  parameter int SIZE_WIDTH   = 4
) (
  input  logic                    clk,
  input  logic                    rst_n,

  // AXI4 B Channel (Write Response)
  input  logic [ID_WIDTH-1:0]     m_axi_bid,
  input  logic [1:0]              m_axi_bresp,
  input  logic                    m_axi_bvalid,
  output logic                    m_axi_bready,

  // AXI4 R Channel (Read Data)
  input  logic [ID_WIDTH-1:0]     m_axi_rid,
  input  logic [DATA_WIDTH-1:0]   m_axi_rdata,
  input  logic [1:0]              m_axi_rresp,
  input  logic                    m_axi_rlast,
  input  logic                    m_axi_rvalid,
  output logic                    m_axi_rready,

  // CAM Query & Release Interfaces
  // B lookup
  output logic                    cam_b_lookup_req,
  output logic [ID_WIDTH-1:0]     cam_b_lookup_id,
  output logic [1:0]              cam_b_lookup_resp,
  input  logic                    cam_b_match_valid,
  input  logic                    cam_b_trans_complete,
  input  logic [SOURCE_WIDTH-1:0] cam_b_match_source,
  input  logic [SIZE_WIDTH-1:0]   cam_b_match_size,
  input  logic                    cam_b_match_error,
  input  logic [31:0]             cam_b_match_latency,

  // R lookup
  output logic                    cam_r_lookup_req,
  output logic [ID_WIDTH-1:0]     cam_r_lookup_id,
  output logic [1:0]              cam_r_lookup_resp,
  output logic                    cam_r_lookup_last,
  input  logic                    cam_r_match_valid,
  input  logic                    cam_r_trans_complete,
  input  logic [SOURCE_WIDTH-1:0] cam_r_match_source,
  input  logic [SIZE_WIDTH-1:0]   cam_r_match_size,
  input  logic                    cam_r_match_error,
  input  logic [31:0]             cam_r_match_latency,

  // TileLink Channel D Interface
  output logic                    tl_d_valid,
  input  logic                    tl_d_ready,
  output tl_axi4_pkg::tl_d_opcode_e tl_d_opcode,
  output logic [1:0]              tl_d_param,
  output logic [SIZE_WIDTH-1:0]   tl_d_size,
  output logic [SOURCE_WIDTH-1:0] tl_d_source,
  output logic [SINK_WIDTH-1:0]   tl_d_sink,
  output logic                    tl_d_denied,
  output logic [DATA_WIDTH-1:0]   tl_d_data,
  output logic                    tl_d_corrupt
);

  // CAM Connections
  assign cam_b_lookup_req  = m_axi_bvalid;
  assign cam_b_lookup_id   = m_axi_bid;
  assign cam_b_lookup_resp = m_axi_bresp;

  assign cam_r_lookup_req  = m_axi_rvalid;
  assign cam_r_lookup_id   = m_axi_rid;
  assign cam_r_lookup_resp = m_axi_rresp;
  assign cam_r_lookup_last = m_axi_rlast;

  // Packed payload for skid buffer
  typedef struct packed {
    tl_axi4_pkg::tl_d_opcode_e opcode;
    logic [1:0]              param;
    logic [SIZE_WIDTH-1:0]   size;
    logic [SOURCE_WIDTH-1:0] source;
    logic [SINK_WIDTH-1:0]   sink;
    logic                    denied;
    logic                    corrupt;
    logic [DATA_WIDTH-1:0]   data;
  } d_payload_t;

  localparam int PAYLOAD_WIDTH = $bits(d_payload_t);

  d_payload_t mux_payload;
  logic       mux_valid;
  logic       mux_ready;

  d_payload_t out_payload;

  // Round-robin arbiter state (0 = R has priority, 1 = B has priority)
  logic arb_priority_q;

  // Determine readiness
  logic r_can_fire;
  logic b_can_fire;

  // B candidate valid: only emits to Channel D if transaction completed
  logic b_wants_tl_d;
  assign b_wants_tl_d = m_axi_bvalid && cam_b_trans_complete;

  // When B is a partial sub-burst completion (trans_complete == 0),
  // it doesn't need TL D emission; it can be acknowledged immediately!
  logic b_intermediate_ack;
  assign b_intermediate_ack = m_axi_bvalid && !cam_b_trans_complete;

  assign r_can_fire = m_axi_rvalid;
  assign b_can_fire = b_wants_tl_d;

  always_comb begin
    mux_valid          = 1'b0;
    mux_payload        = '0;
    m_axi_rready       = 1'b0;
    m_axi_bready       = b_intermediate_ack; // Immediately accept intermediate sub-burst acks

    if (r_can_fire && (!b_can_fire || (arb_priority_q == 1'b0))) begin
      // Serve Read Data
      mux_valid          = 1'b1;
      mux_payload.opcode = tl_axi4_pkg::TL_D_ACCESS_ACK_DATA;
      mux_payload.param  = 2'b00;
      mux_payload.size    = cam_r_match_size;
      mux_payload.source  = cam_r_match_source;
      mux_payload.sink    = '0;
      mux_payload.denied  = (m_axi_rresp == tl_axi4_pkg::AXI_RESP_SLVERR) ||
                            (m_axi_rresp == tl_axi4_pkg::AXI_RESP_DECERR);
      mux_payload.corrupt = cam_r_match_error;
      mux_payload.data    = m_axi_rdata;

      if (mux_ready) begin
        m_axi_rready = 1'b1;
      end
    end else if (b_can_fire) begin
      // Serve Write Ack
      mux_valid          = 1'b1;
      mux_payload.opcode = tl_axi4_pkg::TL_D_ACCESS_ACK;
      mux_payload.param  = 2'b00;
      mux_payload.size    = cam_b_match_size;
      mux_payload.source  = cam_b_match_source;
      mux_payload.sink    = '0;
      mux_payload.denied  = cam_b_match_error;
      mux_payload.corrupt = 1'b0;
      mux_payload.data    = '0;

      if (mux_ready) begin
        m_axi_bready = 1'b1;
      end
    end
  end

  // Priority toggle
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      arb_priority_q <= 1'b0;
    end else begin
      if (mux_valid && mux_ready) begin
        if (m_axi_rready && m_axi_rlast) begin
          arb_priority_q <= 1'b1; // Give B a chance after R burst completes
        end else if (m_axi_bready && !b_intermediate_ack) begin
          arb_priority_q <= 1'b0; // Give R priority after B
        end
      end
    end
  end

  // Output Skid Buffer for zero bubble and registered TL D interface
  tl_skid_buffer #(
    .DATA_WIDTH(PAYLOAD_WIDTH)
  ) u_out_skid (
    .clk     (clk),
    .rst_n   (rst_n),
    .s_valid (mux_valid),
    .s_ready (mux_ready),
    .s_data  (mux_payload),
    .m_valid (tl_d_valid),
    .m_ready (tl_d_ready),
    .m_data  (out_payload)
  );

  // Unpack skid buffer output to TileLink Channel D ports
  assign tl_d_opcode  = out_payload.opcode;
  assign tl_d_param   = out_payload.param;
  assign tl_d_size    = out_payload.size;
  assign tl_d_source  = out_payload.source;
  assign tl_d_sink    = out_payload.sink;
  assign tl_d_denied  = out_payload.denied;
  assign tl_d_corrupt = out_payload.corrupt;
  assign tl_d_data    = out_payload.data;

endmodule : tl_d_transmitter

`endif // TL_D_TRANSMITTER_SV
