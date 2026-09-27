//==============================================================================
// File: tl_sync_fifo.sv
// Description: Parameterized synchronous FIFO with status flags and occupancy
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef TL_SYNC_FIFO_SV
`define TL_SYNC_FIFO_SV

module tl_sync_fifo #(
  parameter int DATA_WIDTH = 32,
  parameter int DEPTH      = 16,
  parameter int ALMOST_FULL_THRESH = 14,
  parameter int ALMOST_EMPTY_THRESH = 2
) (
  input  logic                  clk,
  input  logic                  rst_n,

  // Write Interface
  input  logic                  wr_en,
  input  logic [DATA_WIDTH-1:0] wr_data,
  output logic                  full,
  output logic                  almost_full,

  // Read Interface
  input  logic                  rd_en,
  output logic [DATA_WIDTH-1:0] rd_data,
  output logic                  empty,
  output logic                  almost_empty,

  // Occupancy Status
  output logic [$clog2(DEPTH+1)-1:0] count
);

  localparam int PTR_WIDTH = $clog2(DEPTH);

  // Storage array
  logic [DATA_WIDTH-1:0] mem [DEPTH-1:0];

  logic [PTR_WIDTH-1:0] wr_ptr;
  logic [PTR_WIDTH-1:0] rd_ptr;
  logic [$clog2(DEPTH+1)-1:0] count_q;

  assign full         = (count_q == DEPTH);
  assign empty        = (count_q == '0);
  assign almost_full  = (count_q >= ALMOST_FULL_THRESH);
  assign almost_empty = (count_q <= ALMOST_EMPTY_THRESH);
  assign count        = count_q;

  // Fall-through / direct output
  assign rd_data      = mem[rd_ptr];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr  <= '0;
      rd_ptr  <= '0;
      count_q <= '0;
    end else begin
      case ({wr_en && !full, rd_en && !empty})
        2'b10: begin
          mem[wr_ptr] <= wr_data;
          wr_ptr      <= (wr_ptr == DEPTH - 1) ? '0 : wr_ptr + 1'b1;
          count_q     <= count_q + 1'b1;
        end

        2'b01: begin
          rd_ptr  <= (rd_ptr == DEPTH - 1) ? '0 : rd_ptr + 1'b1;
          count_q <= count_q - 1'b1;
        end

        2'b11: begin
          mem[wr_ptr] <= wr_data;
          wr_ptr      <= (wr_ptr == DEPTH - 1) ? '0 : wr_ptr + 1'b1;
          rd_ptr      <= (rd_ptr == DEPTH - 1) ? '0 : rd_ptr + 1'b1;
          // count remains unchanged
        end

        default: begin
          // No operation
        end
      endcase
    end
  end

endmodule : tl_sync_fifo

`endif // TL_SYNC_FIFO_SV
