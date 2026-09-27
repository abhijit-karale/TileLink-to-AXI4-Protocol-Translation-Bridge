//==============================================================================
// File: tl_source_cam.sv
// Description: Content-Addressable Memory (CAM) for Source-to-AXI-ID mapping
//              and cycle-accurate latency tracker.
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef TL_SOURCE_CAM_SV
`define TL_SOURCE_CAM_SV

import tl_axi4_pkg::*;

module tl_source_cam #(
  parameter int ID_WIDTH     = 4,
  parameter int SOURCE_WIDTH = 4,
  parameter int SIZE_WIDTH   = 4,
  localparam int NUM_ENTRIES = (1 << ID_WIDTH)
) (
  input  logic                    clk,
  input  logic                    rst_n,

  // Allocation Interface (from Bridge Request Dispatcher)
  input  logic                    alloc_req,
  output logic                    alloc_gnt,
  output logic [ID_WIDTH-1:0]     alloc_id,
  input  logic                    alloc_is_write,
  input  logic [SOURCE_WIDTH-1:0] alloc_source,
  input  logic [SIZE_WIDTH-1:0]   alloc_size,
  input  logic [1:0]              alloc_sub_burst_total,

  // Write Response (B Channel) Lookup & Release Interface
  input  logic                    b_lookup_req,
  input  logic [ID_WIDTH-1:0]     b_lookup_id,
  input  logic [1:0]              b_lookup_resp,
  output logic                    b_match_valid,
  output logic                    b_trans_complete,
  output logic [SOURCE_WIDTH-1:0] b_match_source,
  output logic [SIZE_WIDTH-1:0]   b_match_size,
  output logic                    b_match_error,
  output logic [31:0]             b_match_latency,

  // Read Data (R Channel) Lookup & Release Interface
  input  logic                    r_lookup_req,
  input  logic [ID_WIDTH-1:0]     r_lookup_id,
  input  logic [1:0]              r_lookup_resp,
  input  logic                    r_lookup_last,
  output logic                    r_match_valid,
  output logic                    r_trans_complete,
  output logic [SOURCE_WIDTH-1:0] r_match_source,
  output logic [SIZE_WIDTH-1:0]   r_match_size,
  output logic                    r_match_error,
  output logic [31:0]             r_match_latency,

  // Diagnostics & Latency Profiling Registers
  output logic [31:0]             reg_min_latency,
  output logic [31:0]             reg_max_latency,
  output logic [63:0]             reg_total_latency,
  output logic [31:0]             reg_completed_trans,
  output logic [ID_WIDTH:0]       reg_active_count
);

  // Global cycle timer
  logic [31:0] cycle_counter;

  // CAM Storage Fields
  logic [NUM_ENTRIES-1:0]                    entry_valid_q;
  logic [NUM_ENTRIES-1:0]                    entry_is_write_q;
  logic [SOURCE_WIDTH-1:0]                   entry_source_q [NUM_ENTRIES-1:0];
  logic [SIZE_WIDTH-1:0]                     entry_size_q   [NUM_ENTRIES-1:0];
  logic [1:0]                                entry_sub_burst_total_q [NUM_ENTRIES-1:0];
  logic [1:0]                                entry_sub_burst_done_q  [NUM_ENTRIES-1:0];
  logic [31:0]                               entry_timestamp_q       [NUM_ENTRIES-1:0];
  logic [NUM_ENTRIES-1:0]                    entry_error_q;

  // Latency tracking registers
  logic [31:0] min_lat_q;
  logic [31:0] max_lat_q;
  logic [63:0] tot_lat_q;
  logic [31:0] cnt_trans_q;
  logic [ID_WIDTH:0] active_cnt_q;

  assign reg_min_latency     = min_lat_q;
  assign reg_max_latency     = max_lat_q;
  assign reg_total_latency   = tot_lat_q;
  assign reg_completed_trans = cnt_trans_q;
  assign reg_active_count    = active_cnt_q;

  // Free ID Search Logic (Priority encoder)
  logic [ID_WIDTH-1:0] free_id;
  logic                found_free;

  always_comb begin
    free_id    = '0;
    found_free = 1'b0;
    for (int i = 0; i < NUM_ENTRIES; i++) begin
      if (!entry_valid_q[i] && !found_free) begin
        free_id    = i[ID_WIDTH-1:0];
        found_free = 1'b1;
      end
    end
  end

  assign alloc_gnt = alloc_req && found_free;
  assign alloc_id  = free_id;

  // B-Channel Lookup
  logic b_err;
  assign b_err = (b_lookup_resp != tl_axi4_pkg::AXI_RESP_OKAY);

  always_comb begin
    b_match_valid    = 1'b0;
    b_trans_complete = 1'b0;
    b_match_source   = '0;
    b_match_size     = '0;
    b_match_error    = 1'b0;
    b_match_latency  = '0;

    if (b_lookup_req && entry_valid_q[b_lookup_id]) begin
      b_match_valid  = 1'b1;
      b_match_source = entry_source_q[b_lookup_id];
      b_match_size   = entry_size_q[b_lookup_id];
      b_match_error  = entry_error_q[b_lookup_id] || b_err;
      b_match_latency = cycle_counter - entry_timestamp_q[b_lookup_id];

      // Check if this B completes the entire transaction
      if ((entry_sub_burst_done_q[b_lookup_id] + 1'b1) >= entry_sub_burst_total_q[b_lookup_id]) begin
        b_trans_complete = 1'b1;
      end
    end
  end

  // R-Channel Lookup
  logic r_err;
  assign r_err = (r_lookup_resp != tl_axi4_pkg::AXI_RESP_OKAY);

  always_comb begin
    r_match_valid    = 1'b0;
    r_trans_complete = 1'b0;
    r_match_source   = '0;
    r_match_size     = '0;
    r_match_error    = 1'b0;
    r_match_latency  = '0;

    if (r_lookup_req && entry_valid_q[r_lookup_id]) begin
      r_match_valid  = 1'b1;
      r_match_source = entry_source_q[r_lookup_id];
      r_match_size   = entry_size_q[r_lookup_id];
      r_match_error  = entry_error_q[r_lookup_id] || r_err;
      r_match_latency = cycle_counter - entry_timestamp_q[r_lookup_id];

      // If this is the last beat of a sub-burst
      if (r_lookup_last) begin
        if ((entry_sub_burst_done_q[r_lookup_id] + 1'b1) >= entry_sub_burst_total_q[r_lookup_id]) begin
          r_trans_complete = 1'b1;
        end
      end
    end
  end

  // Sequential updates: Allocation, Release, and Latency Tracking
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_counter      <= 32'd0;
      entry_valid_q      <= '0;
      entry_is_write_q   <= '0;
      entry_error_q      <= '0;
      active_cnt_q       <= '0;
      min_lat_q          <= 32'hFFFF_FFFF;
      max_lat_q          <= 32'd0;
      tot_lat_q          <= 64'd0;
      cnt_trans_q        <= 32'd0;

      for (int i = 0; i < NUM_ENTRIES; i++) begin
        entry_source_q[i]          <= '0;
        entry_size_q[i]            <= '0;
        entry_sub_burst_total_q[i] <= '0;
        entry_sub_burst_done_q[i]  <= '0;
        entry_timestamp_q[i]       <= '0;
      end
    end else begin
      cycle_counter <= cycle_counter + 1'b1;

      // 1. Allocation
      if (alloc_gnt) begin
        entry_valid_q[free_id]           <= 1'b1;
        entry_is_write_q[free_id]        <= alloc_is_write;
        entry_source_q[free_id]          <= alloc_source;
        entry_size_q[free_id]            <= alloc_size;
        entry_sub_burst_total_q[free_id] <= alloc_sub_burst_total;
        entry_sub_burst_done_q[free_id]  <= 2'd0;
        entry_timestamp_q[free_id]       <= cycle_counter;
        entry_error_q[free_id]           <= 1'b0;
      end

      // 2. Write Response Update / Deallocation
      if (b_lookup_req && entry_valid_q[b_lookup_id]) begin
        entry_error_q[b_lookup_id] <= entry_error_q[b_lookup_id] || b_err;

        if (b_trans_complete) begin
          entry_valid_q[b_lookup_id] <= 1'b0;

          // Latency Metrics Update
          cnt_trans_q <= cnt_trans_q + 1'b1;
          tot_lat_q   <= tot_lat_q + b_match_latency;
          if (b_match_latency < min_lat_q) min_lat_q <= b_match_latency;
          if (b_match_latency > max_lat_q) max_lat_q <= b_match_latency;
        end else begin
          entry_sub_burst_done_q[b_lookup_id] <= entry_sub_burst_done_q[b_lookup_id] + 1'b1;
        end
      end

      // 3. Read Response Update / Deallocation
      if (r_lookup_req && entry_valid_q[r_lookup_id]) begin
        entry_error_q[r_lookup_id] <= entry_error_q[r_lookup_id] || r_err;

        if (r_lookup_last) begin
          if (r_trans_complete) begin
            entry_valid_q[r_lookup_id] <= 1'b0;

            // Latency Metrics Update
            cnt_trans_q <= cnt_trans_q + 1'b1;
            tot_lat_q   <= tot_lat_q + r_match_latency;
            if (r_match_latency < min_lat_q) min_lat_q <= r_match_latency;
            if (r_match_latency > max_lat_q) max_lat_q <= r_match_latency;
          end else begin
            entry_sub_burst_done_q[r_lookup_id] <= entry_sub_burst_done_q[r_lookup_id] + 1'b1;
          end
        end
      end

      // 4. Active Count Tracking
      // Net change calculation
      case ({alloc_gnt, (b_lookup_req && b_trans_complete) || (r_lookup_req && r_trans_complete)})
        2'b10: active_cnt_q <= active_cnt_q + 1'b1;
        2'b01: active_cnt_q <= active_cnt_q - 1'b1;
        default: active_cnt_q <= active_cnt_q;
      endcase
    end
  end

endmodule : tl_source_cam

`endif // TL_SOURCE_CAM_SV
