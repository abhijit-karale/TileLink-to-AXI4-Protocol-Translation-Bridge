//==============================================================================
// File: tl_axi_write_engine.sv
// Description: AXI4 Write Master Engine managing AW address channel issue,
//              W data burst streaming, wlast generation, and CAM allocation.
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef TL_AXI_WRITE_ENGINE_SV
`define TL_AXI_WRITE_ENGINE_SV

`include "tl_axi4_pkg.sv"

module tl_axi_write_engine #(
  parameter int ADDR_WIDTH   = 32,
  parameter int DATA_WIDTH   = 64,
  parameter int ID_WIDTH     = 4,
  parameter int SOURCE_WIDTH = 4,
  parameter int SIZE_WIDTH   = 4,
  localparam int STRB_WIDTH  = DATA_WIDTH / 8
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
  input  logic [7:0]              cmd_beat_count,

  // CAM Allocation Interface
  output logic                    cam_alloc_req,
  input  logic                    cam_alloc_gnt,
  input  logic [ID_WIDTH-1:0]     cam_alloc_id,
  output logic                    cam_alloc_is_write,
  output logic [SOURCE_WIDTH-1:0] cam_alloc_source,
  output logic [SIZE_WIDTH-1:0]   cam_alloc_size,
  output logic [1:0]              cam_alloc_sub_burst_total,

  // Write Data FIFO Read Interface
  input  logic                    wdata_fifo_empty,
  output logic                    wdata_fifo_rd_en,
  input  logic [DATA_WIDTH-1:0]   wdata_fifo_data,
  input  logic [STRB_WIDTH-1:0]   wdata_fifo_mask,
  input  logic                    wdata_fifo_corrupt,

  // AXI4 AW Channel
  output logic [ID_WIDTH-1:0]     m_axi_awid,
  output logic [ADDR_WIDTH-1:0]   m_axi_awaddr,
  output logic [7:0]              m_axi_awlen,
  output logic [2:0]              m_axi_awsize,
  output logic [1:0]              m_axi_awburst,
  output logic                    m_axi_awlock,
  output logic [3:0]              m_axi_awcache,
  output logic [2:0]              m_axi_awprot,
  output logic [3:0]              m_axi_awqos,
  output logic [3:0]              m_axi_awregion,
  output logic                    m_axi_awvalid,
  input  logic                    m_axi_awready,

  // AXI4 W Channel
  output logic [DATA_WIDTH-1:0]   m_axi_wdata,
  output logic [STRB_WIDTH-1:0]   m_axi_wstrb,
  output logic                    m_axi_wlast,
  output logic                    m_axi_wvalid,
  input  logic                    m_axi_wready
);

  // Registered AXI ID for sub-burst sharing
  logic [ID_WIDTH-1:0] active_id_q, active_id_d;
  logic                holding_id_q, holding_id_d;

  // AW Channel FSM
  typedef enum logic [1:0] {
    AW_IDLE,
    AW_ALLOC,
    AW_ISSUE
  } aw_state_e;

  aw_state_e aw_state_q, aw_state_d;

  logic [ADDR_WIDTH-1:0] latched_awaddr_q, latched_awaddr_d;
  logic [7:0]            latched_awlen_q, latched_awlen_d;
  logic [2:0]            latched_awsize_q, latched_awsize_d;
  logic [ID_WIDTH-1:0]   latched_awid_q, latched_awid_d;

  // W Channel FSM
  typedef enum logic [1:0] {
    W_IDLE,
    W_STREAM
  } w_state_e;

  w_state_e w_state_q, w_state_d;

  logic [7:0] w_beats_remaining_q, w_beats_remaining_d;

  // W-channel FIFO to hold active burst lengths to decouple AW from W
  logic       burst_fifo_wr_en;
  logic [7:0] burst_fifo_wr_len;
  logic       burst_fifo_full;
  logic       burst_fifo_rd_en;
  logic [7:0] burst_fifo_rd_len;
  logic       burst_fifo_empty;

  tl_sync_fifo #(
    .DATA_WIDTH(8),
    .DEPTH(8)
  ) u_burst_len_fifo (
    .clk          (clk),
    .rst_n        (rst_n),
    .wr_en        (burst_fifo_wr_en),
    .wr_data      (burst_fifo_wr_len),
    .full         (burst_fifo_full),
    .almost_full  (),
    .rd_en        (burst_fifo_rd_en),
    .rd_data      (burst_fifo_rd_len),
    .empty        (burst_fifo_empty),
    .almost_empty (),
    .count        ()
  );

  // Static AW signals
  assign m_axi_awburst  = tl_axi4_pkg::AXI_BURST_INCR;
  assign m_axi_awlock   = 1'b0;
  assign m_axi_awcache  = tl_axi4_pkg::AXI_CACHE_NORM_NON;
  assign m_axi_awprot   = 3'b000;
  assign m_axi_awqos    = 4'h0;
  assign m_axi_awregion = 4'h0;

  // AW Outputs
  assign m_axi_awid    = latched_awid_q;
  assign m_axi_awaddr  = latched_awaddr_q;
  assign m_axi_awlen   = latched_awlen_q;
  assign m_axi_awsize  = latched_awsize_q;
  assign m_axi_awvalid = (aw_state_q == AW_ISSUE);

  // CAM allocation defaults
  assign cam_alloc_is_write        = 1'b1;
  assign cam_alloc_source          = cmd_source;
  assign cam_alloc_size            = cmd_tl_size;
  assign cam_alloc_sub_burst_total = cmd_sub_burst_total;

  // AW State Machine
  always_comb begin
    aw_state_d        = aw_state_q;
    latched_awaddr_d  = latched_awaddr_q;
    latched_awlen_d   = latched_awlen_q;
    latched_awsize_d  = latched_awsize_q;
    latched_awid_d    = latched_awid_q;
    active_id_d       = active_id_q;
    holding_id_d      = holding_id_q;

    cmd_ready         = 1'b0;
    cam_alloc_req     = 1'b0;
    burst_fifo_wr_en  = 1'b0;
    burst_fifo_wr_len = cmd_len;

    case (aw_state_q)
      AW_IDLE: begin
        if (cmd_valid && !burst_fifo_full) begin
          if (cmd_is_sub_burst && holding_id_q) begin
            // Reusing previously allocated ID for the 2nd segment
            latched_awid_d    = active_id_q;
            latched_awaddr_d  = cmd_addr;
            latched_awlen_d   = cmd_len;
            latched_awsize_d  = cmd_size;
            holding_id_d      = 1'b0; // used up
            burst_fifo_wr_en  = 1'b1;
            burst_fifo_wr_len = cmd_len;
            cmd_ready         = 1'b1;
            aw_state_d        = AW_ISSUE;
          end else begin
            // Need new CAM ID allocation
            cam_alloc_req = 1'b1;
            if (cam_alloc_gnt) begin
              latched_awid_d    = cam_alloc_id;
              latched_awaddr_d  = cmd_addr;
              latched_awlen_d   = cmd_len;
              latched_awsize_d  = cmd_size;
              burst_fifo_wr_en  = 1'b1;
              burst_fifo_wr_len = cmd_len;
              cmd_ready         = 1'b1;

              if (cmd_is_sub_burst && !cmd_last_sub_burst) begin
                // Save allocated ID for the next sub-burst
                active_id_d  = cam_alloc_id;
                holding_id_d = 1'b1;
              end

              aw_state_d = AW_ISSUE;
            end
          end
        end
      end

      AW_ISSUE: begin
        if (m_axi_awready) begin
          aw_state_d = AW_IDLE;
        end
      end

      default: aw_state_d = AW_IDLE;
    endcase
  end

  // W Channel State Machine and Streaming Logic
  assign m_axi_wdata      = wdata_fifo_data;
  assign m_axi_wstrb      = wdata_fifo_mask;
  assign m_axi_wvalid     = (w_state_q == W_STREAM) && !wdata_fifo_empty;
  assign m_axi_wlast      = (w_state_q == W_STREAM) && (w_beats_remaining_q == 8'd0);
  assign wdata_fifo_rd_en = (w_state_q == W_STREAM) && !wdata_fifo_empty && m_axi_wready;

  always_comb begin
    w_state_d           = w_state_q;
    w_beats_remaining_d = w_beats_remaining_q;
    burst_fifo_rd_en    = 1'b0;

    case (w_state_q)
      W_IDLE: begin
        if (!burst_fifo_empty) begin
          burst_fifo_rd_en    = 1'b1;
          w_beats_remaining_d = burst_fifo_rd_len;
          w_state_d           = W_STREAM;
        end
      end

      W_STREAM: begin
        if (!wdata_fifo_empty && m_axi_wready) begin
          if (w_beats_remaining_q == 8'd0) begin
            // Last beat of this AXI burst
            if (!burst_fifo_empty) begin
              burst_fifo_rd_en    = 1'b1;
              w_beats_remaining_d = burst_fifo_rd_len;
              w_state_d           = W_STREAM;
            end else begin
              w_state_d = W_IDLE;
            end
          end else begin
            w_beats_remaining_d = w_beats_remaining_q - 1'b1;
          end
        end
      end

      default: w_state_d = W_IDLE;
    endcase
  end

  // Registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      aw_state_q          <= AW_IDLE;
      w_state_q           <= W_IDLE;
      latched_awaddr_q    <= '0;
      latched_awlen_q     <= '0;
      latched_awsize_q    <= '0;
      latched_awid_q      <= '0;
      active_id_q         <= '0;
      holding_id_q        <= 1'b0;
      w_beats_remaining_q <= '0;
    end else begin
      aw_state_q          <= aw_state_d;
      w_state_q           <= w_state_d;
      latched_awaddr_q    <= latched_awaddr_d;
      latched_awlen_q     <= latched_awlen_d;
      latched_awsize_q    <= latched_awsize_d;
      latched_awid_q      <= latched_awid_d;
      active_id_q         <= active_id_d;
      holding_id_q        <= holding_id_d;
      w_beats_remaining_q <= w_beats_remaining_d;
    end
  end

endmodule : tl_axi_write_engine

`endif // TL_AXI_WRITE_ENGINE_SV
