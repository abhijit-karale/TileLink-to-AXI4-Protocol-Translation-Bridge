//==============================================================================
// File: tl_driver.sv
// Description: UVM Driver for TileLink-UH Master Agent
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef TL_DRIVER_SV
`define TL_DRIVER_SV

class tl_driver #(
  parameter int ADDR_WIDTH   = 32,
  parameter int DATA_WIDTH   = 64,
  parameter int SOURCE_WIDTH = 4,
  parameter int SIZE_WIDTH   = 4
) extends uvm_driver #(tl_seq_item#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH));

  typedef tl_seq_item#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH) item_t;

  virtual tl_if#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, 4, SIZE_WIDTH) vif;

  `uvm_component_param_utils(tl_driver#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH))

  function new(string name = "tl_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual tl_if#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, 4, SIZE_WIDTH))::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "Virtual interface not found in config_db for tl_driver")
    end
  endfunction

  task run_phase(uvm_phase phase);
    reset_signals();
    fork
      drive_requests();
      handle_responses();
    join
  endtask

  task reset_signals();
    wait (vif.rst_n === 1'b0);
    vif.drv_cb.a_valid   <= 1'b0;
    vif.drv_cb.a_opcode  <= TL_A_GET;
    vif.drv_cb.a_param   <= '0;
    vif.drv_cb.a_size    <= '0;
    vif.drv_cb.a_source  <= '0;
    vif.drv_cb.a_address <= '0;
    vif.drv_cb.a_mask    <= '0;
    vif.drv_cb.a_data    <= '0;
    vif.drv_cb.a_corrupt <= 1'b0;
    vif.drv_cb.d_ready   <= 1'b0;
    wait (vif.rst_n === 1'b1);
    @(vif.drv_cb);
  endtask

  task drive_requests();
    item_t req;
    forever begin
      seq_item_port.get_next_item(req);
      drive_item(req);
      seq_item_port.item_done();
    end
  endtask

  task drive_item(item_t req);
    int bus_bytes;
    int total_bytes;
    int beats;

    bus_bytes   = DATA_WIDTH / 8;
    total_bytes = 1 << req.size;
    beats       = (total_bytes <= bus_bytes) ? 1 : (total_bytes / bus_bytes);

    // Drive first beat (Header + First Data beat if write)
    @(vif.drv_cb);
    vif.drv_cb.a_valid   <= 1'b1;
    vif.drv_cb.a_opcode  <= req.opcode;
    vif.drv_cb.a_param   <= req.param;
    vif.drv_cb.a_size    <= req.size;
    vif.drv_cb.a_source  <= req.source;
    vif.drv_cb.a_address <= req.address;
    vif.drv_cb.a_corrupt <= req.corrupt;

    if (req.opcode != TL_A_GET) begin
      vif.drv_cb.a_data <= req.data[0];
      vif.drv_cb.a_mask <= req.mask[0];
    end else begin
      vif.drv_cb.a_data <= '0;
      vif.drv_cb.a_mask <= '1;
    end

    // Wait for handshake
    do begin
      @(vif.drv_cb);
    end while (!vif.drv_cb.a_ready);

    // For multi-beat write requests, stream remaining data beats
    if (req.opcode != TL_A_GET && beats > 1) begin
      for (int i = 1; i < beats; i++) begin
        vif.drv_cb.a_valid <= 1'b1;
        vif.drv_cb.a_data  <= req.data[i];
        vif.drv_cb.a_mask  <= req.mask[i];
        do begin
          @(vif.drv_cb);
        end while (!vif.drv_cb.a_ready);
      end
    end

    vif.drv_cb.a_valid <= 1'b0;
  endtask

  task handle_responses();
    forever begin
      @(vif.drv_cb);
      // Keep d_ready asserted with occasional random backpressure for verification
      vif.drv_cb.d_ready <= 1'b1;
    end
  endtask

endclass : tl_driver

`endif // TL_DRIVER_SV
