//==============================================================================
// File: axi_monitor.sv
// Description: UVM Monitor for AXI4 Master/Slave Interface
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef AXI_MONITOR_SV
`define AXI_MONITOR_SV

class axi_monitor #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 64,
  parameter int ID_WIDTH   = 4,
  localparam int STRB_WIDTH = DATA_WIDTH / 8
) extends uvm_monitor;

  typedef axi_seq_item#(ADDR_WIDTH, DATA_WIDTH, ID_WIDTH) item_t;

  virtual axi_if#(ADDR_WIDTH, DATA_WIDTH, ID_WIDTH) vif;

  uvm_analysis_port #(item_t) wr_ap;
  uvm_analysis_port #(item_t) rd_ap;

  `uvm_component_param_utils(axi_monitor#(ADDR_WIDTH, DATA_WIDTH, ID_WIDTH))

  function new(string name = "axi_monitor", uvm_component parent = null);
    super.new(name, parent);
    wr_ap = new("wr_ap", this);
    rd_ap = new("rd_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_if#(ADDR_WIDTH, DATA_WIDTH, ID_WIDTH))::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "Virtual interface not found in config_db for axi_monitor")
    end
  endfunction

  task run_phase(uvm_phase phase);
    fork
      monitor_writes();
      monitor_reads();
    join
  endtask

  task monitor_writes();
    forever begin
      item_t item;
      int beats;

      do begin
        @(vif.mon_cb);
      end while (!(vif.mon_cb.awvalid && vif.mon_cb.awready));

      item            = item_t::type_id::create("axi_wr_trans");
      item.trans_type = axi_seq_item#(ADDR_WIDTH, DATA_WIDTH, ID_WIDTH)::AXI_TRANS_WRITE;
      item.id         = vif.mon_cb.awid;
      item.addr       = vif.mon_cb.awaddr;
      item.len        = vif.mon_cb.awlen;
      item.size       = vif.mon_cb.awsize;
      item.burst      = vif.mon_cb.awburst;

      beats           = item.len + 1;
      item.wdata      = new[beats];
      item.wstrb      = new[beats];

      for (int b = 0; b < beats; b++) begin
        do begin
          @(vif.mon_cb);
        end while (!(vif.mon_cb.wvalid && vif.mon_cb.wready));
        item.wdata[b] = vif.mon_cb.wdata;
        item.wstrb[b] = vif.mon_cb.wstrb;
      end

      do begin
        @(vif.mon_cb);
      end while (!(vif.mon_cb.bvalid && vif.mon_cb.bready));
      item.bresp = vif.mon_cb.bresp;

      wr_ap.write(item);
    end
  endtask

  task monitor_reads();
    forever begin
      item_t item;
      int beats;

      do begin
        @(vif.mon_cb);
      end while (!(vif.mon_cb.arvalid && vif.mon_cb.arready));

      item            = item_t::type_id::create("axi_rd_trans");
      item.trans_type = axi_seq_item#(ADDR_WIDTH, DATA_WIDTH, ID_WIDTH)::AXI_TRANS_READ;
      item.id         = vif.mon_cb.arid;
      item.addr       = vif.mon_cb.araddr;
      item.len        = vif.mon_cb.arlen;
      item.size       = vif.mon_cb.arsize;
      item.burst      = vif.mon_cb.arburst;

      beats           = item.len + 1;
      item.rdata      = new[beats];
      item.rresp      = new[beats];

      for (int b = 0; b < beats; b++) begin
        do begin
          @(vif.mon_cb);
        end while (!(vif.mon_cb.rvalid && vif.mon_cb.rready));
        item.rdata[b] = vif.mon_cb.rdata;
        item.rresp[b] = vif.mon_cb.rresp;
      end

      rd_ap.write(item);
    end
  endtask

endclass : axi_monitor

`endif // AXI_MONITOR_SV
