//==============================================================================
// File: tl_a_receiver.sv
// Description: TileLink Channel A Receiver with request classification,
//              burst beat counter, and decoupling FIFO interfaces.
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef TL_A_RECEIVER_SV
`define TL_A_RECEIVER_SV

`include "tl_axi4_pkg.sv"

module tl_a_receiver #(
  parameter int ADDR_WIDTH   = 32,
  parameter int DATA_WIDTH   = 64,
  parameter int SOURCE_WIDTH = 4,
  parameter int SIZE_WIDTH   = 4,
  localparam int MASK_WIDTH  = DATA_WIDTH / 8
) (
  input  logic                    clk,
  input  logic                    rst_n,

  // TileLink Channel A Slave Interface
  input  logic                    tl_a_valid,
  output logic                    tl_a_ready,
  input  tl_axi4_pkg::tl_a_opcode_e tl_a_opcode,
  input  logic [2:0]              tl_a_param,
  input  logic [SIZE_WIDTH-1:0]   tl_a_size,
  input  logic [SOURCE_WIDTH-1:0] tl_a_source,
  input  logic [ADDR_WIDTH-1:0]   tl_a_address,
  input  logic [MASK_WIDTH-1:0]   tl_a_mask,
  input  logic [DATA_WIDTH-1:0]   tl_a_data,
  input  logic                    tl_a_corrupt,

  // Command Interface to Burst Segmenter
  output logic                    req_valid,
  input  logic                    req_ready,
  output tl_axi4_pkg::tl_a_opcode_e req_opcode,
  output logic [ADDR_WIDTH-1:0]   req_address,
  output logic [SIZE_WIDTH-1:0]   req_size,
  output logic [SOURCE_WIDTH-1:0] req_source,

  // Write Data Interface to Write Engine
  output logic                    wdata_fifo_wr_en,
  output logic [DATA_WIDTH-1:0]   wdata_fifo_data,
  output logic [MASK_WIDTH-1:0]   wdata_fifo_mask,
  output logic                    wdata_fifo_corrupt,
  input  logic                    wdata_fifo_full
);

  localparam int BUS_BYTES = DATA_WIDTH / 8;
  localparam int BUS_SIZE  = $clog2(BUS_BYTES);

  // States
  typedef enum logic [1:0] {
    ST_IDLE,
    ST_WRITE_BURST
  } state_e;

  state_e state_q, state_d;

  logic [7:0] beat_count_q, beat_count_d;
  logic [7:0] total_beats_q, total_beats_d;

  logic is_write;
  assign is_write = (tl_a_opcode == tl_axi4_pkg::TL_A_PUT_FULL_DATA) ||
                    (tl_a_opcode == tl_axi4_pkg::TL_A_PUT_PARTIAL_DATA);

  // Calculate total beats for current transaction
  logic [15:0] total_bytes_comb;
  logic [7:0]  calc_beats_comb;

  always_comb begin
    total_bytes_comb = 16'd1 << tl_a_size;
    if (total_bytes_comb <= BUS_BYTES) begin
      calc_beats_comb = 8'd1;
    end else begin
      calc_beats_comb = total_bytes_comb[15:BUS_SIZE];
    end
  end

  // Combinatorial handshake & routing
  always_comb begin
    state_d            = state_q;
    beat_count_d       = beat_count_q;
    total_beats_d      = total_beats_q;

    tl_a_ready         = 1'b0;
    req_valid          = 1'b0;
    req_opcode         = tl_a_opcode;
    req_address        = tl_a_address;
    req_size           = tl_a_size;
    req_source         = tl_a_source;

    wdata_fifo_wr_en   = 1'b0;
    wdata_fifo_data    = tl_a_data;
    wdata_fifo_mask    = tl_a_mask;
    wdata_fifo_corrupt = tl_a_corrupt;

    case (state_q)
      ST_IDLE: begin
        if (tl_a_valid) begin
          if (is_write) begin
            // Need both command downstream ready AND write data FIFO not full
            if (req_ready && !wdata_fifo_full) begin
              req_valid        = 1'b1;
              wdata_fifo_wr_en = 1'b1;
              tl_a_ready       = 1'b1;

              if (calc_beats_comb > 8'd1) begin
                state_d       = ST_WRITE_BURST;
                total_beats_d = calc_beats_comb;
                beat_count_d  = 8'd1; // first beat consumed
              end
            end
          end else begin
            // Read or other non-write (Get)
            if (req_ready) begin
              req_valid  = 1'b1;
              tl_a_ready = 1'b1;
            end
          end
        end
      end

      ST_WRITE_BURST: begin
        // Subsequent write data beats of the burst (no new command is sent to segmenter)
        if (tl_a_valid && !wdata_fifo_full) begin
          wdata_fifo_wr_en = 1'b1;
          tl_a_ready       = 1'b1;
          beat_count_d     = beat_count_q + 1'b1;

          if (beat_count_d == total_beats_q) begin
            state_d = ST_IDLE;
          end
        end
      end

      default: state_d = ST_IDLE;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q       <= ST_IDLE;
      beat_count_q  <= '0;
      total_beats_q <= '0;
    end else begin
      state_q       <= state_d;
      beat_count_q  <= beat_count_d;
      total_beats_q <= total_beats_d;
    end
  end

endmodule : tl_a_receiver

`endif // TL_A_RECEIVER_SV
