//==============================================================================
// File: tl_axi4_pkg.sv
// Description: TileLink-UH and AXI4 Protocol Definitions, Structs, and Constants
// Author: Abhijit Karale
// Tech Node & Target: SkyWater 130nm @ 200 MHz
//==============================================================================

`ifndef TL_AXI4_PKG_SV
`define TL_AXI4_PKG_SV

package tl_axi4_pkg;

  //----------------------------------------------------------------------------
  // TileLink Channel A Opcodes (UH - Uncached Heavyweight)
  //----------------------------------------------------------------------------
  typedef enum logic [2:0] {
    TL_A_PUT_FULL_DATA    = 3'b000,
    TL_A_PUT_PARTIAL_DATA = 3'b001,
    TL_A_ARITHMETIC_DATA  = 3'b010,
    TL_A_LOGICAL_DATA     = 3'b011,
    TL_A_GET              = 3'b100,
    TL_A_INTENT           = 3'b110
  } tl_a_opcode_e;

  //----------------------------------------------------------------------------
  // TileLink Channel D Opcodes
  //----------------------------------------------------------------------------
  typedef enum logic [2:0] {
    TL_D_ACCESS_ACK       = 3'b000,
    TL_D_ACCESS_ACK_DATA  = 3'b001,
    TL_D_HINT_ACK         = 3'b010
  } tl_d_opcode_e;

  //----------------------------------------------------------------------------
  // AXI4 Burst Types
  //----------------------------------------------------------------------------
  typedef enum logic [1:0] {
    AXI_BURST_FIXED       = 2'b00,
    AXI_BURST_INCR        = 2'b01,
    AXI_BURST_WRAP        = 2'b10,
    AXI_BURST_RESERVED    = 2'b11
  } axi_burst_e;

  //----------------------------------------------------------------------------
  // AXI4 Response Codes
  //----------------------------------------------------------------------------
  typedef enum logic [1:0] {
    AXI_RESP_OKAY         = 2'b00,
    AXI_RESP_EXOKAY       = 2'b01,
    AXI_RESP_SLVERR       = 2'b10,
    AXI_RESP_DECERR       = 2'b11
  } axi_resp_e;

  //----------------------------------------------------------------------------
  // AXI4 Cache Encodings (Normal Non-cacheable bufferable / modifiable)
  //----------------------------------------------------------------------------
  localparam logic [3:0] AXI_CACHE_DEV_NONBUF = 4'b0000;
  localparam logic [3:0] AXI_CACHE_DEV_BUF    = 4'b0001;
  localparam logic [3:0] AXI_CACHE_NORM_NON   = 4'b0010;
  localparam logic [3:0] AXI_CACHE_NORM_BUF   = 4'b0011;

  //----------------------------------------------------------------------------
  // Helper Functions
  //----------------------------------------------------------------------------
  // Returns number of bytes for a given AXI size (2^size)
  function automatic int size_to_bytes(input logic [2:0] size);
    return (1 << size);
  endfunction

  // Returns ceil(log2(n))
  function automatic int clog2(input int val);
    int result;
    result = 0;
    val = val - 1;
    while (val > 0) begin
      val = val >> 1;
      result++;
    end
    return (result == 0) ? 1 : result;
  endfunction

  // Checks if a transaction at addr with length len_bytes crosses a 4KB boundary
  function automatic logic crosses_4kb_boundary(
    input logic [63:0] addr,
    input logic [15:0] total_bytes
  );
    logic [11:0] offset;
    offset = addr[11:0];
    return ((offset + total_bytes) > 13'd4096);
  endfunction

endpackage : tl_axi4_pkg

`endif // TL_AXI4_PKG_SV
