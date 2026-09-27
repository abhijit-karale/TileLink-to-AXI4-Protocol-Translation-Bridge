//==============================================================================
// File: tl_skid_buffer.sv
// Description: Zero-bubble elastic skid buffer for 100% pipeline throughput
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef TL_SKID_BUFFER_SV
`define TL_SKID_BUFFER_SV

module tl_skid_buffer #(
  parameter int DATA_WIDTH = 32
) (
  input  logic                  clk,
  input  logic                  rst_n,

  // Upstream Interface
  input  logic                  s_valid,
  output logic                  s_ready,
  input  logic [DATA_WIDTH-1:0] s_data,

  // Downstream Interface
  output logic                  m_valid,
  input  logic                  m_ready,
  output logic [DATA_WIDTH-1:0] m_data
);

  // Storage registers
  logic [DATA_WIDTH-1:0] main_data_q;
  logic [DATA_WIDTH-1:0] skid_data_q;
  logic                  main_valid_q;
  logic                  skid_valid_q;

  // Transfer conditions
  logic s_fire;
  logic m_fire;

  assign s_fire = s_valid && s_ready;
  assign m_fire = m_valid && m_ready;

  // Upstream ready is asserted as long as skid register is not occupied
  assign s_ready = !skid_valid_q;

  // Downstream valid is asserted if either main or skid has valid data
  assign m_valid = main_valid_q || skid_valid_q;

  // Downstream data multiplexing: skid data has priority if present
  assign m_data  = skid_valid_q ? skid_data_q : main_data_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      main_valid_q <= 1'b0;
      skid_valid_q <= 1'b0;
      main_data_q  <= '0;
      skid_data_q  <= '0;
    end else begin
      case ({s_fire, m_fire})
        2'b00: begin
          // No incoming, no outgoing: maintain state
        end

        2'b01: begin
          // Downstream took data, no incoming
          if (skid_valid_q) begin
            skid_valid_q <= 1'b0;
          end else begin
            main_valid_q <= 1'b0;
          end
        end

        2'b10: begin
          // Upstream sent data, downstream stalled
          if (!main_valid_q) begin
            main_valid_q <= 1'b1;
            main_data_q  <= s_data;
          end else begin
            // Main was full, move to skid
            skid_valid_q <= 1'b1;
            skid_data_q  <= s_data;
          end
        end

        2'b11: begin
          // Both upstream and downstream fired in the same cycle
          if (skid_valid_q) begin
            // Downstream consumed skid data, incoming moves to skid
            skid_data_q  <= s_data;
          end else begin
            // Direct pass-through into main register
            main_data_q  <= s_data;
            main_valid_q <= 1'b1;
          end
        end
      endcase
    end
  end

endmodule : tl_skid_buffer

`endif // TL_SKID_BUFFER_SV
