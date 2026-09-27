//==============================================================================
// File: tl_burst_segmenter.sv
// Description: Burst Segmentation Engine handling TileLink size decoding,
//              AXI burst lengths (awlen/arlen), and 4KB boundary split logic.
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef TL_BURST_SEGMENTER_SV
`define TL_BURST_SEGMENTER_SV

import tl_axi4_pkg::*;

module tl_burst_segmenter #(
  parameter int ADDR_WIDTH   = 32,
  parameter int DATA_WIDTH   = 64,
  parameter int SOURCE_WIDTH = 4,
  parameter int SIZE_WIDTH   = 4
) (
  input  logic                    clk,
  input  logic                    rst_n,

  // Input from TL Channel A Receiver
  input  logic                    req_valid,
  output logic                    req_ready,
  input  tl_axi4_pkg::tl_a_opcode_e req_opcode,
  input  logic [ADDR_WIDTH-1:0]   req_address,
  input  logic [SIZE_WIDTH-1:0]   req_size,
  input  logic [SOURCE_WIDTH-1:0] req_source,

  // Output to AXI Command Engines (Read or Write)
  output logic                    cmd_valid,
  input  logic                    cmd_ready,
  output logic                    cmd_is_write,
  output logic [ADDR_WIDTH-1:0]   cmd_addr,
  output logic [7:0]              cmd_len,       // AXI burst length (len = beats - 1)
  output logic [2:0]              cmd_size,      // AXI burst size (bytes/beat)
  output logic [SOURCE_WIDTH-1:0] cmd_source,
  output logic [SIZE_WIDTH-1:0]   cmd_tl_size,
  output logic                    cmd_is_sub_burst,
  output logic                    cmd_last_sub_burst,
  output logic [1:0]              cmd_sub_burst_total,
  output logic [7:0]              cmd_beat_count // Total data beats for this segment
);

  localparam int BUS_BYTES = DATA_WIDTH / 8;
  localparam int BUS_SIZE  = $clog2(BUS_BYTES); // log2(BUS_BYTES)

  // Internal state machine for emitting sub-bursts
  typedef enum logic [1:0] {
    ST_IDLE,
    ST_EMIT_SEG0,
    ST_EMIT_SEG1
  } state_e;

  state_e state_q, state_d;

  // Latch transaction parameters during multi-segment split
  logic [ADDR_WIDTH-1:0]   latched_addr_q, latched_addr_d;
  logic [SIZE_WIDTH-1:0]   latched_size_q, latched_size_d;
  logic [SOURCE_WIDTH-1:0] latched_source_q, latched_source_d;
  logic                    latched_is_write_q, latched_is_write_d;
  logic [7:0]              seg0_len_q, seg0_len_d;
  logic [7:0]              seg1_len_q, seg1_len_d;
  logic [ADDR_WIDTH-1:0]   seg1_addr_q, seg1_addr_d;
  logic                    split_required_q, split_required_d;

  // Combinatorial calculations for incoming request
  logic [15:0] total_bytes;
  logic [15:0] total_beats;
  logic [12:0] bytes_to_4kb;
  logic [15:0] seg0_bytes;
  logic [15:0] seg1_bytes;
  logic [15:0] seg0_beats;
  logic [15:0] seg1_beats;
  logic        crosses_4kb;
  logic        is_write_comb;

  assign is_write_comb = (req_opcode == tl_axi4_pkg::TL_A_PUT_FULL_DATA) ||
                         (req_opcode == tl_axi4_pkg::TL_A_PUT_PARTIAL_DATA);

  // Compute total bytes = 2^req_size
  always_comb begin
    total_bytes = 16'd1 << req_size;

    // Number of data beats
    if (total_bytes <= BUS_BYTES) begin
      total_beats = 16'd1;
    end else begin
      total_beats = total_bytes >> BUS_SIZE;
    end

    // 4KB boundary distance: bytes left in current 4KB page
    bytes_to_4kb = 13'd4096 - {1'b0, req_address[11:0]};

    // Check if total transfer spans across 4KB boundary
    if ((req_address[11:0] != 12'd0) && (total_bytes > bytes_to_4kb)) begin
      crosses_4kb = 1'b1;
      seg0_bytes  = bytes_to_4kb;
      seg1_bytes  = total_bytes - bytes_to_4kb;
      seg0_beats  = (seg0_bytes <= BUS_BYTES) ? 16'd1 : (seg0_bytes >> BUS_SIZE);
      seg1_beats  = (seg1_bytes <= BUS_BYTES) ? 16'd1 : (seg1_bytes >> BUS_SIZE);
    end else begin
      crosses_4kb = 1'b0;
      seg0_bytes  = total_bytes;
      seg1_bytes  = 16'd0;
      seg0_beats  = total_beats;
      seg1_beats  = 16'd0;
    end
  end

  // State Machine and Output Logic
  always_comb begin
    state_d             = state_q;
    latched_addr_d      = latched_addr_q;
    latched_size_d      = latched_size_q;
    latched_source_d    = latched_source_q;
    latched_is_write_d  = latched_is_write_q;
    seg0_len_d          = seg0_len_q;
    seg1_len_d          = seg1_len_q;
    seg1_addr_d         = seg1_addr_q;
    split_required_d    = split_required_q;

    req_ready           = 1'b0;
    cmd_valid           = 1'b0;
    cmd_is_write        = 1'b0;
    cmd_addr            = '0;
    cmd_len             = 8'd0;
    cmd_size            = BUS_SIZE[2:0];
    cmd_source          = '0;
    cmd_tl_size         = '0;
    cmd_is_sub_burst    = 1'b0;
    cmd_last_sub_burst  = 1'b1;
    cmd_sub_burst_total = 2'd1;
    cmd_beat_count      = 8'd1;

    case (state_q)
      ST_IDLE: begin
        if (req_valid) begin
          if (crosses_4kb) begin
            // Split into two sub-bursts
            cmd_valid           = 1'b1;
            cmd_is_write        = is_write_comb;
            cmd_addr            = req_address;
            cmd_len             = seg0_beats[7:0] - 8'd1;
            cmd_size            = BUS_SIZE[2:0];
            cmd_source          = req_source;
            cmd_tl_size         = req_size;
            cmd_is_sub_burst    = 1'b1;
            cmd_last_sub_burst  = 1'b0;
            cmd_sub_burst_total = 2'd2;
            cmd_beat_count      = seg0_beats[7:0];

            if (cmd_ready) begin
              // Accepted segment 0, advance to emit segment 1
              req_ready          = 1'b1;
              latched_addr_d     = req_address;
              latched_size_d     = req_size;
              latched_source_d   = req_source;
              latched_is_write_d = is_write_comb;
              seg1_len_d         = seg1_beats[7:0] - 8'd1;
              seg1_addr_d        = req_address + seg0_bytes;
              state_d            = ST_EMIT_SEG1;
            end
          end else begin
            // Single burst directly forwarded
            cmd_valid           = 1'b1;
            cmd_is_write        = is_write_comb;
            cmd_addr            = req_address;
            cmd_len             = (total_beats > 0) ? (total_beats[7:0] - 8'd1) : 8'd0;
            cmd_size            = BUS_SIZE[2:0];
            cmd_source          = req_source;
            cmd_tl_size         = req_size;
            cmd_is_sub_burst    = 1'b0;
            cmd_last_sub_burst  = 1'b1;
            cmd_sub_burst_total = 2'd1;
            cmd_beat_count      = (total_beats > 0) ? total_beats[7:0] : 8'd1;

            if (cmd_ready) begin
              req_ready = 1'b1;
            end
          end
        end
      end

      ST_EMIT_SEG1: begin
        // Emit second sub-burst
        cmd_valid           = 1'b1;
        cmd_is_write        = latched_is_write_q;
        cmd_addr            = seg1_addr_q;
        cmd_len             = seg1_len_q;
        cmd_size            = BUS_SIZE[2:0];
        cmd_source          = latched_source_q;
        cmd_tl_size         = latched_size_q;
        cmd_is_sub_burst    = 1'b1;
        cmd_last_sub_burst  = 1'b1;
        cmd_sub_burst_total = 2'd2;
        cmd_beat_count      = seg1_len_q + 8'd1;

        if (cmd_ready) begin
          state_d = ST_IDLE;
        end
      end

      default: state_d = ST_IDLE;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q            <= ST_IDLE;
      latched_addr_q     <= '0;
      latched_size_q     <= '0;
      latched_source_q   <= '0;
      latched_is_write_q <= 1'b0;
      seg0_len_q         <= '0;
      seg1_len_q         <= '0;
      seg1_addr_q        <= '0;
      split_required_q   <= 1'b0;
    end else begin
      state_q            <= state_d;
      latched_addr_q     <= latched_addr_d;
      latched_size_q     <= latched_size_d;
      latched_source_q   <= latched_source_d;
      latched_is_write_q <= latched_is_write_d;
      seg0_len_q         <= seg0_len_d;
      seg1_len_q         <= seg1_len_d;
      seg1_addr_q        <= seg1_addr_d;
      split_required_q   <= split_required_d;
    end
  end

endmodule : tl_burst_segmenter

`endif // TL_BURST_SEGMENTER_SV
