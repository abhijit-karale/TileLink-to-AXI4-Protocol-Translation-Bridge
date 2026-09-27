//==============================================================================
// File: tl_monitor.sv
// Description: UVM Monitor for TileLink-UH Interface
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef TL_MONITOR_SV
`define TL_MONITOR_SV

class tl_monitor #(
  parameter int ADDR_WIDTH   = 32,
  parameter int DATA_WIDTH   = 64,
  parameter int SOURCE_WIDTH = 4,
  parameter int SIZE_WIDTH   = 4
) extends uvm_monitor;

  typedef tl_seq_item#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH) item_t;

  virtual tl_if#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, 4, SIZE_WIDTH) vif;

  uvm_analysis_port #(item_t) a_ap;
  uvm_analysis_port #(item_t) d_ap;

  `uvm_component_param_utils(tl_monitor#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, SIZE_WIDTH))

  function new(string name = "tl_monitor", uvm_component parent = null);
    super.new(name, parent);
    a_ap = new("a_ap", this);
    d_ap = new("d_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual tl_if#(ADDR_WIDTH, DATA_WIDTH, SOURCE_WIDTH, 4, SIZE_WIDTH))::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "Virtual interface not found in config_db for tl_monitor")
    end
  endfunction

  task run_phase(uvm_phase phase);
    fork
      monitor_channel_a();
      monitor_channel_d();
    join
  endtask

  task monitor_channel_a();
    int bus_bytes;
    int total_bytes;
    int beats;
    item_t item;

    bus_bytes = DATA_WIDTH / 8;

    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.a_valid && vif.mon_cb.a_ready) begin
        item          = item_t::type_id::create("item_a");
        item.opcode   = vif.mon_cb.a_opcode;
        item.param    = vif.mon_cb.a_param;
        item.size     = vif.mon_cb.a_size;
        item.source   = vif.mon_cb.a_source;
        item.address  = vif.mon_cb.a_address;
        item.corrupt  = vif.mon_cb.a_corrupt;
        item.start_time = $time;

        total_bytes = 1 << item.size;
        beats       = (total_bytes <= bus_bytes) ? 1 : (total_bytes / bus_bytes);

        if (item.opcode != TL_A_GET) begin
          item.data = new[beats];
          item.mask = new[beats];
          item.data[0] = vif.mon_cb.a_data;
          item.mask[0] = vif.mon_cb.a_mask;

          for (int i = 1; i < beats; i++) begin
            do begin
              @(vif.mon_cb);
            end while (!(vif.mon_cb.a_valid && vif.mon_cb.a_ready));
            item.data[i] = vif.mon_cb.a_data;
            item.mask[i] = vif.mon_cb.a_mask;
          end
        end

        a_ap.write(item);
      end
    end
  endtask

  task monitor_channel_d();
    item_t item;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.d_valid && vif.mon_cb.d_ready) begin
        item          = item_t::type_id::create("item_d");
        item.d_opcode = vif.mon_cb.d_opcode;
        item.d_param  = vif.mon_cb.d_param;
        item.d_size   = vif.mon_cb.d_size;
        item.d_source = vif.mon_cb.d_source;
        item.d_denied = vif.mon_cb.d_denied;
        item.d_corrupt = vif.mon_cb.d_corrupt;
        item.end_time = $time;

        item.d_data   = new[1];
        item.d_data[0] = vif.mon_cb.d_data;

        d_ap.write(item);
      end
    end
  endtask

endclass : tl_monitor

`endif // TL_MONITOR_SV
