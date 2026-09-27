//==============================================================================
// File: axi_driver.sv
// Description: UVM Reactive Slave Driver for AXI4 VIP with internal memory model
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef AXI_DRIVER_SV
`define AXI_DRIVER_SV

class axi_driver #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 64,
  parameter int ID_WIDTH   = 4,
  localparam int STRB_WIDTH = DATA_WIDTH / 8
) extends uvm_driver #(axi_seq_item#(ADDR_WIDTH, DATA_WIDTH, ID_WIDTH));

  typedef axi_seq_item#(ADDR_WIDTH, DATA_WIDTH, ID_WIDTH) item_t;

  virtual axi_if#(ADDR_WIDTH, DATA_WIDTH, ID_WIDTH) vif;

  // Associative array memory model (byte addressable)
  logic [7:0] memory [logic [ADDR_WIDTH-1:0]];

  // Programmable response latency (in clock cycles)
  int read_delay_min  = 0;
  int read_delay_max  = 2;
  int write_delay_min = 0;
  int write_delay_max = 2;

  // Error injection control
  bit inject_error = 1'b0;
  logic [1:0] error_resp = tl_axi4_pkg::AXI_RESP_SLVERR;

  `uvm_component_param_utils(axi_driver#(ADDR_WIDTH, DATA_WIDTH, ID_WIDTH))

  function new(string name = "axi_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_if#(ADDR_WIDTH, DATA_WIDTH, ID_WIDTH))::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "Virtual interface not found in config_db for axi_driver")
    end
  endfunction

  task run_phase(uvm_phase phase);
    reset_signals();
    fork
      handle_writes();
      handle_reads();
    join
  endtask

  task reset_signals();
    wait (vif.rst_n === 1'b0);
    vif.drv_cb.awready <= 1'b0;
    vif.drv_cb.wready  <= 1'b0;
    vif.drv_cb.bvalid  <= 1'b0;
    vif.drv_cb.bid     <= '0;
    vif.drv_cb.bresp   <= 2'b00;
    vif.drv_cb.buser   <= '0;
    vif.drv_cb.arready <= 1'b0;
    vif.drv_cb.rvalid  <= 1'b0;
    vif.drv_cb.rid     <= '0;
    vif.drv_cb.rdata   <= '0;
    vif.drv_cb.rresp   <= 2'b00;
    vif.drv_cb.rlast   <= 1'b0;
    vif.drv_cb.ruser   <= '0;
    wait (vif.rst_n === 1'b1);
    @(vif.drv_cb);
    vif.drv_cb.awready <= 1'b1;
    vif.drv_cb.wready  <= 1'b1;
    vif.drv_cb.arready <= 1'b1;
  endtask

  // Structure to hold in-flight write context
  typedef struct {
    logic [ID_WIDTH-1:0]   awid;
    logic [ADDR_WIDTH-1:0] awaddr;
    logic [7:0]            awlen;
    logic [2:0]            awsize;
  } aw_ctx_t;

  aw_ctx_t aw_queue[$];

  task handle_writes();
    fork
      // AW Channel consumer
      forever begin
        @(vif.drv_cb);
        if (vif.drv_cb.awvalid && vif.drv_cb.awready) begin
          aw_ctx_t ctx;
          ctx.awid   = vif.drv_cb.awid;
          ctx.awaddr = vif.drv_cb.awaddr;
          ctx.awlen  = vif.drv_cb.awlen;
          ctx.awsize = vif.drv_cb.awsize;
          aw_queue.push_back(ctx);
        end
      end

      // W Channel consumer & B Channel driver
      forever begin
        aw_ctx_t active_ctx;
        int beats;
        logic [ADDR_WIDTH-1:0] cur_addr;
        int bytes_per_beat;

        wait (aw_queue.size() > 0);
        active_ctx = aw_queue.pop_front();
        beats      = active_ctx.awlen + 1;
        cur_addr   = active_ctx.awaddr;
        bytes_per_beat = 1 << active_ctx.awsize;

        for (int b = 0; b < beats; b++) begin
          do begin
            @(vif.drv_cb);
          end while (!(vif.drv_cb.wvalid && vif.drv_cb.wready));

          // Store bytes in memory model according to write strobes
          for (int byte_idx = 0; byte_idx < STRB_WIDTH; byte_idx++) begin
            if (vif.drv_cb.wstrb[byte_idx]) begin
              memory[cur_addr + byte_idx] = vif.drv_cb.wdata[byte_idx*8 +: 8];
            end
          end
          cur_addr = cur_addr + bytes_per_beat;
        end

        // B response delay
        repeat ($urandom_range(write_delay_min, write_delay_max)) @(vif.drv_cb);

        vif.drv_cb.bvalid <= 1'b1;
        vif.drv_cb.bid    <= active_ctx.awid;
        vif.drv_cb.bresp  <= inject_error ? error_resp : tl_axi4_pkg::AXI_RESP_OKAY;

        do begin
          @(vif.drv_cb);
        end while (!vif.drv_cb.bready);

        vif.drv_cb.bvalid <= 1'b0;
      end
    join
  endtask

  task handle_reads();
    forever begin
      logic [ID_WIDTH-1:0]   arid;
      logic [ADDR_WIDTH-1:0] araddr;
      logic [7:0]            arlen;
      logic [2:0]            arsize;
      int                    beats;
      int                    bytes_per_beat;
      logic [ADDR_WIDTH-1:0] cur_addr;

      do begin
        @(vif.drv_cb);
      end while (!(vif.drv_cb.arvalid && vif.drv_cb.arready));

      arid           = vif.drv_cb.arid;
      araddr         = vif.drv_cb.araddr;
      arlen          = vif.drv_cb.arlen;
      arsize         = vif.drv_cb.arsize;
      beats          = arlen + 1;
      bytes_per_beat = 1 << arsize;
      cur_addr       = araddr;

      // Programmable access latency
      repeat ($urandom_range(read_delay_min, read_delay_max)) @(vif.drv_cb);

      // Stream read data beats
      for (int b = 0; b < beats; b++) begin
        logic [DATA_WIDTH-1:0] rdata_beat;
        rdata_beat = '0;

        for (int byte_idx = 0; byte_idx < STRB_WIDTH; byte_idx++) begin
          if (memory.exists(cur_addr + byte_idx)) begin
            rdata_beat[byte_idx*8 +: 8] = memory[cur_addr + byte_idx];
          end else begin
            // Default deterministic pattern if unwritten
            rdata_beat[byte_idx*8 +: 8] = cur_addr[7:0] + byte_idx[7:0];
          end
        end

        vif.drv_cb.rvalid <= 1'b1;
        vif.drv_cb.rid    <= arid;
        vif.drv_cb.rdata  <= rdata_beat;
        vif.drv_cb.rresp  <= inject_error ? error_resp : tl_axi4_pkg::AXI_RESP_OKAY;
        vif.drv_cb.rlast  <= (b == beats - 1);

        do begin
          @(vif.drv_cb);
        end while (!vif.drv_cb.rready);

        cur_addr = cur_addr + bytes_per_beat;
      end

      vif.drv_cb.rvalid <= 1'b0;
      vif.drv_cb.rlast  <= 1'b0;
    end
  endtask

endclass : axi_driver

`endif // AXI_DRIVER_SV
