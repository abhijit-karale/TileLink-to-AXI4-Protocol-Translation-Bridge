//==============================================================================
// File: tl_axi4_bridge_top.sv
// Description: Production-grade TileLink-UH to AXI4 Protocol Translation Bridge.
//              Features 4KB burst segmentation, transaction tagging CAM,
//              latency profiling tracker, and zero-bubble pipelining.
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef TL_AXI4_BRIDGE_TOP_SV
`define TL_AXI4_BRIDGE_TOP_SV

`include "tl_axi4_pkg.sv"
`include "tl_skid_buffer.sv"
`include "tl_sync_fifo.sv"
`include "tl_source_cam.sv"
`include "tl_burst_segmenter.sv"
`include "tl_a_receiver.sv"
`include "tl_axi_write_engine.sv"
`include "tl_axi_read_engine.sv"
`include "tl_d_transmitter.sv"

module tl_axi4_bridge_top #(
  parameter int ADDR_WIDTH      = 32,
  parameter int DATA_WIDTH      = 64,
  parameter int SOURCE_WIDTH    = 4,
  parameter int SINK_WIDTH      = 4,
  parameter int ID_WIDTH        = 4,
  parameter int SIZE_WIDTH      = 4,
  parameter int USER_WIDTH      = 1,
  parameter int WDATA_FIFO_DP   = 16,
  localparam int STRB_WIDTH     = DATA_WIDTH / 8
) (
  input  logic                      clk,
  input  logic                      rst_n,

  //============================================================================
  // TileLink-UH Slave Interface
  //============================================================================
  // Channel A (Request)
  input  logic                      tl_a_valid,
  output logic                      tl_a_ready,
  input  tl_axi4_pkg::tl_a_opcode_e tl_a_opcode,
  input  logic [2:0]                tl_a_param,
  input  logic [SIZE_WIDTH-1:0]     tl_a_size,
  input  logic [SOURCE_WIDTH-1:0]   tl_a_source,
  input  logic [ADDR_WIDTH-1:0]     tl_a_address,
  input  logic [STRB_WIDTH-1:0]     tl_a_mask,
  input  logic [DATA_WIDTH-1:0]     tl_a_data,
  input  logic                      tl_a_corrupt,

  // Channel D (Response)
  output logic                      tl_d_valid,
  input  logic                      tl_d_ready,
  output tl_axi4_pkg::tl_d_opcode_e tl_d_opcode,
  output logic [1:0]                tl_d_param,
  output logic [SIZE_WIDTH-1:0]     tl_d_size,
  output logic [SOURCE_WIDTH-1:0]   tl_d_source,
  output logic [SINK_WIDTH-1:0]     tl_d_sink,
  output logic                      tl_d_denied,
  output logic [DATA_WIDTH-1:0]     tl_d_data,
  output logic                      tl_d_corrupt,

  //============================================================================
  // AXI4 Full Master Interface
  //============================================================================
  // Write Address Channel (AW)
  output logic [ID_WIDTH-1:0]       m_axi_awid,
  output logic [ADDR_WIDTH-1:0]     m_axi_awaddr,
  output logic [7:0]                m_axi_awlen,
  output logic [2:0]                m_axi_awsize,
  output logic [1:0]                m_axi_awburst,
  output logic                      m_axi_awlock,
  output logic [3:0]                m_axi_awcache,
  output logic [2:0]                m_axi_awprot,
  output logic [3:0]                m_axi_awqos,
  output logic [3:0]                m_axi_awregion,
  output logic [USER_WIDTH-1:0]     m_axi_awuser,
  output logic                      m_axi_awvalid,
  input  logic                      m_axi_awready,

  // Write Data Channel (W)
  output logic [DATA_WIDTH-1:0]     m_axi_wdata,
  output logic [STRB_WIDTH-1:0]     m_axi_wstrb,
  output logic                      m_axi_wlast,
  output logic [USER_WIDTH-1:0]     m_axi_wuser,
  output logic                      m_axi_wvalid,
  input  logic                      m_axi_wready,

  // Write Response Channel (B)
  input  logic [ID_WIDTH-1:0]       m_axi_bid,
  input  logic [1:0]                m_axi_bresp,
  input  logic [USER_WIDTH-1:0]     m_axi_buser,
  input  logic                      m_axi_bvalid,
  output logic                      m_axi_bready,

  // Read Address Channel (AR)
  output logic [ID_WIDTH-1:0]       m_axi_arid,
  output logic [ADDR_WIDTH-1:0]     m_axi_araddr,
  output logic [7:0]                m_axi_arlen,
  output logic [2:0]                m_axi_arsize,
  output logic [1:0]                m_axi_arburst,
  output logic                      m_axi_arlock,
  output logic [3:0]                m_axi_arcache,
  output logic [2:0]                m_axi_arprot,
  output logic [3:0]                m_axi_arqos,
  output logic [3:0]                m_axi_arregion,
  output logic [USER_WIDTH-1:0]     m_axi_aruser,
  output logic                      m_axi_arvalid,
  input  logic                      m_axi_arready,

  // Read Data Channel (R)
  input  logic [ID_WIDTH-1:0]       m_axi_rid,
  input  logic [DATA_WIDTH-1:0]     m_axi_rdata,
  input  logic [1:0]                m_axi_rresp,
  input  logic                      m_axi_rlast,
  input  logic [USER_WIDTH-1:0]     m_axi_ruser,
  input  logic                      m_axi_rvalid,
  output logic                      m_axi_rready,

  //============================================================================
  // Profiling & Latency Diagnostics
  //============================================================================
  output logic [31:0]               stat_min_latency,
  output logic [31:0]               stat_max_latency,
  output logic [63:0]               stat_total_latency,
  output logic [31:0]               stat_completed_trans,
  output logic [ID_WIDTH:0]         stat_active_count
);

  assign m_axi_awuser = '0;
  assign m_axi_wuser  = '0;
  assign m_axi_aruser = '0;

  //----------------------------------------------------------------------------
  // Internal Interconnect Signals
  //----------------------------------------------------------------------------
  // TileLink Channel A Ingress Skid Buffer
  typedef struct packed {
    tl_axi4_pkg::tl_a_opcode_e opcode;
    logic [2:0]              param;
    logic [SIZE_WIDTH-1:0]   size;
    logic [SOURCE_WIDTH-1:0] source;
    logic [ADDR_WIDTH-1:0]   address;
    logic [STRB_WIDTH-1:0]   mask;
    logic [DATA_WIDTH-1:0]   data;
    logic                    corrupt;
  } a_payload_t;

  a_payload_t a_in_payload, a_buf_payload;
  logic       a_buf_valid, a_buf_ready;

  assign a_in_payload.opcode  = tl_a_opcode;
  assign a_in_payload.param   = tl_a_param;
  assign a_in_payload.size    = tl_a_size;
  assign a_in_payload.source  = tl_a_source;
  assign a_in_payload.address = tl_a_address;
  assign a_in_payload.mask    = tl_a_mask;
  assign a_in_payload.data    = tl_a_data;
  assign a_in_payload.corrupt = tl_a_corrupt;

  tl_skid_buffer #(
    .DATA_WIDTH($bits(a_payload_t))
  ) u_a_ingress_skid (
    .clk     (clk),
    .rst_n   (rst_n),
    .s_valid (tl_a_valid),
    .s_ready (tl_a_ready),
    .s_data  (a_in_payload),
    .m_valid (a_buf_valid),
    .m_ready (a_buf_ready),
    .m_data  (a_buf_payload)
  );

  // Receiver -> Segmenter
  logic                      rcv_req_valid;
  logic                      rcv_req_ready;
  tl_axi4_pkg::tl_a_opcode_e rcv_req_opcode;
  logic [ADDR_WIDTH-1:0]     rcv_req_address;
  logic [SIZE_WIDTH-1:0]     rcv_req_size;
  logic [SOURCE_WIDTH-1:0]   rcv_req_source;

  // Receiver -> Write Data FIFO
  logic                      wdata_fifo_wr_en;
  logic [DATA_WIDTH-1:0]     wdata_fifo_wr_data;
  logic [STRB_WIDTH-1:0]     wdata_fifo_wr_mask;
  logic                      wdata_fifo_wr_corrupt;
  logic                      wdata_fifo_full;
  logic                      wdata_fifo_rd_en;
  logic [DATA_WIDTH-1:0]     wdata_fifo_rd_data;
  logic [STRB_WIDTH-1:0]     wdata_fifo_rd_mask;
  logic                      wdata_fifo_rd_corrupt;
  logic                      wdata_fifo_empty;

  typedef struct packed {
    logic [DATA_WIDTH-1:0] data;
    logic [STRB_WIDTH-1:0] mask;
    logic                  corrupt;
  } wdata_item_t;

  wdata_item_t wdata_wr_item, wdata_rd_item;
  assign wdata_wr_item.data    = wdata_fifo_wr_data;
  assign wdata_wr_item.mask    = wdata_fifo_wr_mask;
  assign wdata_wr_item.corrupt = wdata_fifo_wr_corrupt;

  assign wdata_fifo_rd_data    = wdata_rd_item.data;
  assign wdata_fifo_rd_mask    = wdata_rd_item.mask;
  assign wdata_fifo_rd_corrupt = wdata_rd_item.corrupt;

  tl_sync_fifo #(
    .DATA_WIDTH($bits(wdata_item_t)),
    .DEPTH(WDATA_FIFO_DP)
  ) u_wdata_fifo (
    .clk          (clk),
    .rst_n        (rst_n),
    .wr_en        (wdata_fifo_wr_en),
    .wr_data      (wdata_wr_item),
    .full         (wdata_fifo_full),
    .almost_full  (),
    .rd_en        (wdata_fifo_rd_en),
    .rd_data      (wdata_rd_item),
    .empty        (wdata_fifo_empty),
    .almost_empty (),
    .count        ()
  );

  tl_a_receiver #(
    .ADDR_WIDTH   (ADDR_WIDTH),
    .DATA_WIDTH   (DATA_WIDTH),
    .SOURCE_WIDTH (SOURCE_WIDTH),
    .SIZE_WIDTH   (SIZE_WIDTH)
  ) u_a_receiver (
    .clk                (clk),
    .rst_n              (rst_n),
    .tl_a_valid         (a_buf_valid),
    .tl_a_ready         (a_buf_ready),
    .tl_a_opcode        (a_buf_payload.opcode),
    .tl_a_param         (a_buf_payload.param),
    .tl_a_size          (a_buf_payload.size),
    .tl_a_source        (a_buf_payload.source),
    .tl_a_address       (a_buf_payload.address),
    .tl_a_mask          (a_buf_payload.mask),
    .tl_a_data          (a_buf_payload.data),
    .tl_a_corrupt       (a_buf_payload.corrupt),
    .req_valid          (rcv_req_valid),
    .req_ready          (rcv_req_ready),
    .req_opcode         (rcv_req_opcode),
    .req_address        (rcv_req_address),
    .req_size           (rcv_req_size),
    .req_source         (rcv_req_source),
    .wdata_fifo_wr_en   (wdata_fifo_wr_en),
    .wdata_fifo_data    (wdata_fifo_wr_data),
    .wdata_fifo_mask    (wdata_fifo_wr_mask),
    .wdata_fifo_corrupt (wdata_fifo_wr_corrupt),
    .wdata_fifo_full    (wdata_fifo_full)
  );

  // Burst Segmenter -> Command Demux
  logic                    seg_cmd_valid;
  logic                    seg_cmd_ready;
  logic                    seg_cmd_is_write;
  logic [ADDR_WIDTH-1:0]   seg_cmd_addr;
  logic [7:0]              seg_cmd_len;
  logic [2:0]              seg_cmd_size;
  logic [SOURCE_WIDTH-1:0] seg_cmd_source;
  logic [SIZE_WIDTH-1:0]   seg_cmd_tl_size;
  logic                    seg_cmd_is_sub_burst;
  logic                    seg_cmd_last_sub_burst;
  logic [1:0]              seg_cmd_sub_burst_total;
  logic [7:0]              seg_cmd_beat_count;

  tl_burst_segmenter #(
    .ADDR_WIDTH   (ADDR_WIDTH),
    .DATA_WIDTH   (DATA_WIDTH),
    .SOURCE_WIDTH (SOURCE_WIDTH),
    .SIZE_WIDTH   (SIZE_WIDTH)
  ) u_segmenter (
    .clk                 (clk),
    .rst_n               (rst_n),
    .req_valid           (rcv_req_valid),
    .req_ready           (rcv_req_ready),
    .req_opcode          (rcv_req_opcode),
    .req_address         (rcv_req_address),
    .req_size            (rcv_req_size),
    .req_source          (rcv_req_source),
    .cmd_valid           (seg_cmd_valid),
    .cmd_ready           (seg_cmd_ready),
    .cmd_is_write        (seg_cmd_is_write),
    .cmd_addr            (seg_cmd_addr),
    .cmd_len             (seg_cmd_len),
    .cmd_size            (seg_cmd_size),
    .cmd_source          (seg_cmd_source),
    .cmd_tl_size         (seg_cmd_tl_size),
    .cmd_is_sub_burst    (seg_cmd_is_sub_burst),
    .cmd_last_sub_burst  (seg_cmd_last_sub_burst),
    .cmd_sub_burst_total (seg_cmd_sub_burst_total),
    .cmd_beat_count      (seg_cmd_beat_count)
  );

  // Demux to Write Engine and Read Engine
  logic wr_cmd_valid, wr_cmd_ready;
  logic rd_cmd_valid, rd_cmd_ready;

  assign wr_cmd_valid  = seg_cmd_valid && seg_cmd_is_write;
  assign rd_cmd_valid  = seg_cmd_valid && !seg_cmd_is_write;
  assign seg_cmd_ready = seg_cmd_is_write ? wr_cmd_ready : rd_cmd_ready;

  // CAM Allocation Arbitration
  logic                    cam_alloc_req;
  logic                    cam_alloc_gnt;
  logic [ID_WIDTH-1:0]     cam_alloc_id;
  logic                    cam_alloc_is_write;
  logic [SOURCE_WIDTH-1:0] cam_alloc_source;
  logic [SIZE_WIDTH-1:0]   cam_alloc_size;
  logic [1:0]              cam_alloc_sub_burst_total;

  logic                    wr_cam_alloc_req, wr_cam_alloc_gnt;
  logic [ID_WIDTH-1:0]     wr_cam_alloc_id;
  logic                    wr_cam_alloc_is_write;
  logic [SOURCE_WIDTH-1:0] wr_cam_alloc_source;
  logic [SIZE_WIDTH-1:0]   wr_cam_alloc_size;
  logic [1:0]              wr_cam_alloc_sub_burst_total;

  logic                    rd_cam_alloc_req, rd_cam_alloc_gnt;
  logic [ID_WIDTH-1:0]     rd_cam_alloc_id;
  logic                    rd_cam_alloc_is_write;
  logic [SOURCE_WIDTH-1:0] rd_cam_alloc_source;
  logic [SIZE_WIDTH-1:0]   rd_cam_alloc_size;
  logic [1:0]              rd_cam_alloc_sub_burst_total;

  always_comb begin
    if (wr_cam_alloc_req) begin
      cam_alloc_req             = 1'b1;
      cam_alloc_is_write        = wr_cam_alloc_is_write;
      cam_alloc_source          = wr_cam_alloc_source;
      cam_alloc_size            = wr_cam_alloc_size;
      cam_alloc_sub_burst_total = wr_cam_alloc_sub_burst_total;
      wr_cam_alloc_gnt          = cam_alloc_gnt;
      wr_cam_alloc_id           = cam_alloc_id;

      rd_cam_alloc_gnt          = 1'b0;
      rd_cam_alloc_id           = '0;
    end else begin
      cam_alloc_req             = rd_cam_alloc_req;
      cam_alloc_is_write        = rd_cam_alloc_is_write;
      cam_alloc_source          = rd_cam_alloc_source;
      cam_alloc_size            = rd_cam_alloc_size;
      cam_alloc_sub_burst_total = rd_cam_alloc_sub_burst_total;
      rd_cam_alloc_gnt          = cam_alloc_gnt;
      rd_cam_alloc_id           = cam_alloc_id;

      wr_cam_alloc_gnt          = 1'b0;
      wr_cam_alloc_id           = '0;
    end
  end

  // AXI Write Engine
  tl_axi_write_engine #(
    .ADDR_WIDTH   (ADDR_WIDTH),
    .DATA_WIDTH   (DATA_WIDTH),
    .ID_WIDTH     (ID_WIDTH),
    .SOURCE_WIDTH (SOURCE_WIDTH),
    .SIZE_WIDTH   (SIZE_WIDTH)
  ) u_write_engine (
    .clk                       (clk),
    .rst_n                     (rst_n),
    .cmd_valid                 (wr_cmd_valid),
    .cmd_ready                 (wr_cmd_ready),
    .cmd_addr                  (seg_cmd_addr),
    .cmd_len                   (seg_cmd_len),
    .cmd_size                  (seg_cmd_size),
    .cmd_source                (seg_cmd_source),
    .cmd_tl_size               (seg_cmd_tl_size),
    .cmd_is_sub_burst          (seg_cmd_is_sub_burst),
    .cmd_last_sub_burst        (seg_cmd_last_sub_burst),
    .cmd_sub_burst_total       (seg_cmd_sub_burst_total),
    .cmd_beat_count            (seg_cmd_beat_count),
    .cam_alloc_req             (wr_cam_alloc_req),
    .cam_alloc_gnt             (wr_cam_alloc_gnt),
    .cam_alloc_id              (wr_cam_alloc_id),
    .cam_alloc_is_write        (wr_cam_alloc_is_write),
    .cam_alloc_source          (wr_cam_alloc_source),
    .cam_alloc_size            (wr_cam_alloc_size),
    .cam_alloc_sub_burst_total (wr_cam_alloc_sub_burst_total),
    .wdata_fifo_empty          (wdata_fifo_empty),
    .wdata_fifo_rd_en          (wdata_fifo_rd_en),
    .wdata_fifo_data           (wdata_fifo_rd_data),
    .wdata_fifo_mask           (wdata_fifo_rd_mask),
    .wdata_fifo_corrupt        (wdata_fifo_rd_corrupt),
    .m_axi_awid                (m_axi_awid),
    .m_axi_awaddr              (m_axi_awaddr),
    .m_axi_awlen               (m_axi_awlen),
    .m_axi_awsize              (m_axi_awsize),
    .m_axi_awburst             (m_axi_awburst),
    .m_axi_awlock              (m_axi_awlock),
    .m_axi_awcache             (m_axi_awcache),
    .m_axi_awprot              (m_axi_awprot),
    .m_axi_awqos               (m_axi_awqos),
    .m_axi_awregion            (m_axi_awregion),
    .m_axi_awvalid             (m_axi_awvalid),
    .m_axi_awready             (m_axi_awready),
    .m_axi_wdata               (m_axi_wdata),
    .m_axi_wstrb               (m_axi_wstrb),
    .m_axi_wlast               (m_axi_wlast),
    .m_axi_wvalid              (m_axi_wvalid),
    .m_axi_wready              (m_axi_wready)
  );

  // AXI Read Engine
  tl_axi_read_engine #(
    .ADDR_WIDTH   (ADDR_WIDTH),
    .DATA_WIDTH   (DATA_WIDTH),
    .ID_WIDTH     (ID_WIDTH),
    .SOURCE_WIDTH (SOURCE_WIDTH),
    .SIZE_WIDTH   (SIZE_WIDTH)
  ) u_read_engine (
    .clk                       (clk),
    .rst_n                     (rst_n),
    .cmd_valid                 (rd_cmd_valid),
    .cmd_ready                 (rd_cmd_ready),
    .cmd_addr                  (seg_cmd_addr),
    .cmd_len                   (seg_cmd_len),
    .cmd_size                  (seg_cmd_size),
    .cmd_source                (seg_cmd_source),
    .cmd_tl_size               (seg_cmd_tl_size),
    .cmd_is_sub_burst          (seg_cmd_is_sub_burst),
    .cmd_last_sub_burst        (seg_cmd_last_sub_burst),
    .cmd_sub_burst_total       (seg_cmd_sub_burst_total),
    .cam_alloc_req             (rd_cam_alloc_req),
    .cam_alloc_gnt             (rd_cam_alloc_gnt),
    .cam_alloc_id              (rd_cam_alloc_id),
    .cam_alloc_is_write        (rd_cam_alloc_is_write),
    .cam_alloc_source          (rd_cam_alloc_source),
    .cam_alloc_size            (rd_cam_alloc_size),
    .cam_alloc_sub_burst_total (rd_cam_alloc_sub_burst_total),
    .m_axi_arid                (m_axi_arid),
    .m_axi_araddr              (m_axi_araddr),
    .m_axi_arlen               (m_axi_arlen),
    .m_axi_arsize              (m_axi_arsize),
    .m_axi_arburst             (m_axi_arburst),
    .m_axi_arlock              (m_axi_arlock),
    .m_axi_arcache             (m_axi_arcache),
    .m_axi_arprot              (m_axi_arprot),
    .m_axi_arqos               (m_axi_arqos),
    .m_axi_arregion            (m_axi_arregion),
    .m_axi_arvalid             (m_axi_arvalid),
    .m_axi_arready             (m_axi_arready)
  );

  // CAM Lookup signals from D Transmitter
  logic                    cam_b_lookup_req;
  logic [ID_WIDTH-1:0]     cam_b_lookup_id;
  logic [1:0]              cam_b_lookup_resp;
  logic                    cam_b_match_valid;
  logic                    cam_b_trans_complete;
  logic [SOURCE_WIDTH-1:0] cam_b_match_source;
  logic [SIZE_WIDTH-1:0]   cam_b_match_size;
  logic                    cam_b_match_error;
  logic [31:0]             cam_b_match_latency;

  logic                    cam_r_lookup_req;
  logic [ID_WIDTH-1:0]     cam_r_lookup_id;
  logic [1:0]              cam_r_lookup_resp;
  logic                    cam_r_lookup_last;
  logic                    cam_r_match_valid;
  logic                    cam_r_trans_complete;
  logic [SOURCE_WIDTH-1:0] cam_r_match_source;
  logic [SIZE_WIDTH-1:0]   cam_r_match_size;
  logic                    cam_r_match_error;
  logic [31:0]             cam_r_match_latency;

  // Source-to-ID CAM & Latency Tracker
  tl_source_cam #(
    .ID_WIDTH     (ID_WIDTH),
    .SOURCE_WIDTH (SOURCE_WIDTH),
    .SIZE_WIDTH   (SIZE_WIDTH)
  ) u_cam (
    .clk                   (clk),
    .rst_n                 (rst_n),
    .alloc_req             (cam_alloc_req),
    .alloc_gnt             (cam_alloc_gnt),
    .alloc_id              (cam_alloc_id),
    .alloc_is_write        (cam_alloc_is_write),
    .alloc_source          (cam_alloc_source),
    .alloc_size            (cam_alloc_size),
    .alloc_sub_burst_total (cam_alloc_sub_burst_total),
    .b_lookup_req          (cam_b_lookup_req),
    .b_lookup_id           (cam_b_lookup_id),
    .b_lookup_resp         (cam_b_lookup_resp),
    .b_match_valid         (cam_b_match_valid),
    .b_trans_complete      (cam_b_trans_complete),
    .b_match_source        (cam_b_match_source),
    .b_match_size          (cam_b_match_size),
    .b_match_error         (cam_b_match_error),
    .b_match_latency       (cam_b_match_latency),
    .r_lookup_req          (cam_r_lookup_req),
    .r_lookup_id           (cam_r_lookup_id),
    .r_lookup_resp         (cam_r_lookup_resp),
    .r_lookup_last         (cam_r_lookup_last),
    .r_match_valid         (cam_r_match_valid),
    .r_trans_complete      (cam_r_trans_complete),
    .r_match_source        (cam_r_match_source),
    .r_match_size          (cam_r_match_size),
    .r_match_error         (cam_r_match_error),
    .r_match_latency       (cam_r_match_latency),
    .reg_min_latency       (stat_min_latency),
    .reg_max_latency       (stat_max_latency),
    .reg_total_latency     (stat_total_latency),
    .reg_completed_trans   (stat_completed_trans),
    .reg_active_count      (stat_active_count)
  );

  // TileLink Channel D Transmitter
  tl_d_transmitter #(
    .DATA_WIDTH   (DATA_WIDTH),
    .ID_WIDTH     (ID_WIDTH),
    .SOURCE_WIDTH (SOURCE_WIDTH),
    .SINK_WIDTH   (SINK_WIDTH),
    .SIZE_WIDTH   (SIZE_WIDTH)
  ) u_d_transmitter (
    .clk                  (clk),
    .rst_n                (rst_n),
    .m_axi_bid            (m_axi_bid),
    .m_axi_bresp          (m_axi_bresp),
    .m_axi_bvalid         (m_axi_bvalid),
    .m_axi_bready         (m_axi_bready),
    .m_axi_rid            (m_axi_rid),
    .m_axi_rdata          (m_axi_rdata),
    .m_axi_rresp          (m_axi_rresp),
    .m_axi_rlast          (m_axi_rlast),
    .m_axi_rvalid         (m_axi_rvalid),
    .m_axi_rready         (m_axi_rready),
    .cam_b_lookup_req     (cam_b_lookup_req),
    .cam_b_lookup_id      (cam_b_lookup_id),
    .cam_b_lookup_resp    (cam_b_lookup_resp),
    .cam_b_match_valid    (cam_b_match_valid),
    .cam_b_trans_complete (cam_b_trans_complete),
    .cam_b_match_source   (cam_b_match_source),
    .cam_b_match_size     (cam_b_match_size),
    .cam_b_match_error    (cam_b_match_error),
    .cam_b_match_latency  (cam_b_match_latency),
    .cam_r_lookup_req     (cam_r_lookup_req),
    .cam_r_lookup_id      (cam_r_lookup_id),
    .cam_r_lookup_resp    (cam_r_lookup_resp),
    .cam_r_lookup_last    (cam_r_lookup_last),
    .cam_r_match_valid    (cam_r_match_valid),
    .cam_r_trans_complete (cam_r_trans_complete),
    .cam_r_match_source   (cam_r_match_source),
    .cam_r_match_size     (cam_r_match_size),
    .cam_r_match_error    (cam_r_match_error),
    .cam_r_match_latency  (cam_r_match_latency),
    .tl_d_valid           (tl_d_valid),
    .tl_d_ready           (tl_d_ready),
    .tl_d_opcode          (tl_d_opcode),
    .tl_d_param           (tl_d_param),
    .tl_d_size            (tl_d_size),
    .tl_d_source          (tl_d_source),
    .tl_d_sink            (tl_d_sink),
    .tl_d_denied          (tl_d_denied),
    .tl_d_data            (tl_d_data),
    .tl_d_corrupt         (tl_d_corrupt)
  );

endmodule : tl_axi4_bridge_top

`endif // TL_AXI4_BRIDGE_TOP_SV
