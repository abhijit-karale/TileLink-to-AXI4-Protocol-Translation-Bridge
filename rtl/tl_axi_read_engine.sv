//==============================================================================
// File: tl_axi_read_engine.sv
// Description: AXI4 Read Master Engine managing AR address channel issue
//              and CAM allocation with sub-burst handling.
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef TL_AXI_READ_ENGINE_SV
`define TL_AXI_READ_ENGINE_SV

import tl_axi4_pkg::*;

module tl_axi_read_engine #(
  parameter int ADDR_WIDTH   = 32,
  parameter int DATA_WIDTH   = 64,
  parameter int ID_WIDTH     = 4,
  parameter int SOURCE_WIDTH = 4,
  parameter int SIZE_WIDTH   = 4
) (
  input  logic                    clk,
  input  logic                    rst_n,

  // Command from Burst Segmenter
  input  logic                    cmd_valid,
  output logic                    cmd_ready,
  input  logic [ADDR_WIDTH-1:0]   cmd_addr,
  input  logic [7:0]              cmd_len,
  input  logic [2:0]              cmd_size,
  input  logic [SOURCE_WIDTH-1:0] cmd_source,
  input  logic [SIZE_WIDTH-1:0]   cmd_tl_size,
  input  logic                    cmd_is_sub_burst,
  input  logic                    cmd_last_sub_burst,
  input  logic [1:0]              cmd_sub_burst_total,

  // CAM Allocation Interface
  output logic                    cam_alloc_req,
  input  logic                    cam_alloc_gnt,
  input  logic [ID_WIDTH-1:0]     cam_alloc_id,
  output logic                    cam_alloc_is_write,
  output logic [SOURCE_WIDTH-1:0] cam_alloc_source,
  output logic [SIZE_WIDTH-1:0]   cam_alloc_size,
  output logic [1:0]              cam_alloc_sub_burst_total,

  // AXI4 AR Channel
  output logic [ID_WIDTH-1:0]     m_axi_arid,
  output logic [ADDR_WIDTH-1:0]   m_axi_araddr,
  output logic [7:0]              m_axi_arlen,
  output logic [2:0]              m_axi_arsize,
  output logic [1:0]              m_axi_arburst,
  output logic                    m_axi_arlock,
  output logic [3:0]              m_axi_arcache,
  output logic [2:0]              m_axi_arprot,
  output logic [3:0]              m_axi_arqos,
  output logic [3:0]              m_axi_arregion,
  output logic                    m_axi_arvalid,
  input  logic                    m_axi_arready
);

  // States
  typedef enum logic [1:0] {
    AR_IDLE,
    AR_ISSUE
  } ar_state_e;

  ar_state_e ar_state_q, ar_state_d;

  // Registered transaction info
  logic [ADDR_WIDTH-1:0] latched_araddr_q, latched_araddr_d;
  logic [7:0]            latched_arlen_q, latched_arlen_d;
  logic [2:0]            latched_arsize_q, latched_arsize_d;
  logic [ID_WIDTH-1:0]   latched_arid_q, latched_arid_d;

  logic [ID_WIDTH-1:0]   active_id_q, active_id_d;
  logic                  holding_id_q, holding_id_d;

  // Static AR signals
  assign m_axi_arburst  = tl_axi4_pkg::AXI_BURST_INCR;
  assign m_axi_arlock   = 1'b0;
  assign m_axi_arcache  = tl_axi4_pkg::AXI_CACHE_NORM_NON;
  assign m_axi_arprot   = 3'b000;
  assign m_axi_arqos    = 4'h0;
  assign m_axi_arregion = 4'h0;

  // AR Outputs
  assign m_axi_arid    = latched_arid_q;
  assign m_axi_araddr  = latched_araddr_q;
  assign m_axi_arlen   = latched_arlen_q;
  assign m_axi_arsize  = latched_arsize_q;
  assign m_axi_arvalid = (ar_state_q == AR_ISSUE);

  // CAM allocation defaults
  assign cam_alloc_is_write        = 1'b0;
  assign cam_alloc_source          = cmd_source;
  assign cam_alloc_size            = cmd_tl_size;
  assign cam_alloc_sub_burst_total = cmd_sub_burst_total;

  always_comb begin
    ar_state_d       = ar_state_q;
    latched_araddr_d = latched_araddr_q;
    latched_arlen_d  = latched_arlen_q;
    latched_arsize_d = latched_arsize_q;
    latched_arid_d   = latched_arid_q;
    active_id_d      = active_id_q;
    holding_id_d     = holding_id_q;

    cmd_ready        = 1'b0;
    cam_alloc_req    = 1'b0;

    case (ar_state_q)
      AR_IDLE: begin
        if (cmd_valid) begin
          if (cmd_is_sub_burst && holding_id_q) begin
            // Reuse ID for second sub-burst
            latched_arid_d   = active_id_q;
            latched_araddr_d = cmd_addr;
            latched_arlen_d  = cmd_len;
            latched_arsize_d = cmd_size;
            holding_id_d     = 1'b0;
            cmd_ready        = 1'b1;
            ar_state_d       = AR_ISSUE;
          end else begin
            cam_alloc_req = 1'b1;
            if (cam_alloc_gnt) begin
              latched_arid_d   = cam_alloc_id;
              latched_araddr_d = cmd_addr;
              latched_arlen_d  = cmd_len;
              latched_arsize_d = cmd_size;
              cmd_ready        = 1'b1;

              if (cmd_is_sub_burst && !cmd_last_sub_burst) begin
                active_id_d  = cam_alloc_id;
                holding_id_d = 1'b1;
              end

              ar_state_d = AR_ISSUE;
            end
          end
        end
      end

      AR_ISSUE: begin
        if (m_axi_arready) begin
          ar_state_d = AR_IDLE;
        end
      end

      default: ar_state_d = AR_IDLE;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ar_state_q       <= AR_IDLE;
      latched_araddr_q <= '0;
      latched_arlen_q  <= '0;
      latched_arsize_q <= '0;
      latched_arid_q   <= '0;
      active_id_q      <= '0;
      holding_id_q     <= 1'b0;
    end else begin
      ar_state_q       <= ar_state_d;
      latched_araddr_q <= latched_araddr_d;
      latched_arlen_q  <= latched_arlen_d;
      latched_arsize_q <= latched_arsize_d;
      latched_arid_q   <= latched_arid_d;
      active_id_q      <= active_id_d;
      holding_id_q     <= holding_id_d;
    end
  end

endmodule : tl_axi_read_engine

`endif // TL_AXI_READ_ENGINE_SV
