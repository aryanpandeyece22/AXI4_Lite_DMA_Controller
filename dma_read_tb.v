`timescale 1us/1ps
module dma_tb;

    // Declare wires/regs
reg        clk;
reg        rst;
reg        trigger;
reg [5:0]  length;
reg [31:0] src_addr;
reg [31:0] dest_addr;
wire        done;

reg  [31:0] RDATA;
wire [1:0]  RRESP;
reg         RVALID;
wire        RREADY;

wire [31:0] ARADDR;
wire        ARVALID;
wire [2:0]  ARPROT;
reg         ARREADY;

// Instantiate the module
DMA_READ dma_reader_inst (
    .clk        (clk),
    .rst        (rst),
    
    .trigger    (trigger),
    .length     (length),
    .src_addr   (src_addr),
    .dest_addr  (dest_addr),
    .done       (done),
    
    .RDATA      (RDATA),
    .RRESP      (RRESP),
    .RVALID     (RVALID),
    .RREADY     (RREADY),

    .ARADDR     (ARADDR),
    .ARVALID    (ARVALID),
    .ARPROT     (ARPROT),
    .ARREADY    (ARREADY)
);

always #5 clk = ~clk;
integer i;

initial begin
    $dumpfile("dma_read.vcd");
    $dumpvars(0,dma_tb);
    
    clk = 0;
    rst = 1;
    trigger = 0;
    RDATA = 0;
    RVALID = 0;
    ARREADY = 0;

    repeat (2) @(posedge clk);  // Wait for reset sync
    rst = 0;

    @(posedge clk);
    trigger <= 1;
    src_addr <= 32'h0000000A;
    length   <= 6'd4;

    @(posedge clk);
    trigger <= 0;

    // Start first transfer
    @(posedge clk);
    ARREADY <= 1;

    wait (ARVALID && ARREADY);
    $display("[%0t] Handshake 1: ARVALID=%b, ARREADY=%b", $time, ARVALID, ARREADY);
    
    @(posedge clk); // Let ARVALID go low
    ARREADY <= 0;

    // Provide read data
    // @(posedge clk);
    RDATA <= 32'h12345678;
    RVALID <= 1;

    wait (RREADY);
    @(posedge clk);  // FSM consumes RDATA
    RVALID <= 0;
    RDATA  <= 32'h00000000;  // Optional clear

    // Start second transfer
    ARREADY <= 1;

    wait (ARVALID && ARREADY);
    $display("[%0t] Handshake 2: ARVALID=%b, ARREADY=%b", $time, ARVALID, ARREADY);
    @(posedge clk);
    ARREADY <= 0;

    // @(posedge clk);
    RDATA <= 32'hABCDEF12;
    RVALID <= 1;

    wait (RREADY);
    @(posedge clk);
    RVALID <= 0;

    #30

    ////////////////////////////////////////////////////////////////

    @(posedge clk);
    trigger <= 1;
    src_addr <= 32'h0000000A;
    length   <= 6'd7;

    @(posedge clk);
    trigger <= 0;

    // Start first transfer
    @(posedge clk);
    ARREADY <= 1;

    wait (ARVALID && ARREADY);
    $display("[%0t] Handshake 1: ARVALID=%b, ARREADY=%b", $time, ARVALID, ARREADY);
    
    @(posedge clk); // Let ARVALID go low
    ARREADY <= 0;

    // Provide read data
    // @(posedge clk);
    RDATA  <= 32'h12345678;
    RVALID <= 1;

    wait (RREADY);
    @(posedge clk);  // FSM consumes RDATA
    RVALID <= 0;
    RDATA  <= 32'h00000000;  // Optional clear

    // Start second transfer
    ARREADY <= 1;

    wait (ARVALID && ARREADY);
    $display("[%0t] Handshake 2: ARVALID=%b, ARREADY=%b", $time, ARVALID, ARREADY);
    @(posedge clk);
    ARREADY <= 0;

    // @(posedge clk);
    RDATA  <= 32'hABCDEF12;
    RVALID <= 1;

    wait (RREADY);
    @(posedge clk);
    RVALID <= 0;

    // Start third transfer
    ARREADY <= 1;

    wait (ARVALID && ARREADY);
    $display("[%0t] Handshake 2: ARVALID=%b, ARREADY=%b", $time, ARVALID, ARREADY);
    @(posedge clk);
    ARREADY <= 0;
    RDATA  <= 32'h87654321;
    RVALID <= 1;

    wait (RREADY);
    @(posedge clk);
    RVALID <= 0;

    //////////////////////////////////////////////////////

    @(posedge clk);
    trigger <= 1;
    src_addr <= 32'h0000000B;
    length   <= 6'd2;

    @(posedge clk);
    trigger <= 0;

    // Start first transfer
    @(posedge clk);
    ARREADY <= 1;

    wait (ARVALID && ARREADY);
    $display("[%0t] Handshake 1: ARVALID=%b, ARREADY=%b", $time, ARVALID, ARREADY);
    
    @(posedge clk); // Let ARVALID go low
    ARREADY <= 0;

    // Provide read data
    //@(posedge clk);
    RDATA  <= 32'h12345678;
    RVALID <= 1;

    wait (RREADY);
    @(posedge clk);  // FSM consumes RDATA
    RVALID <= 0;
    RDATA  <= 32'h00000000;  // Optional clear

    // Start second transfer
    @(posedge clk);
    ARREADY <= 1;

    wait (ARVALID && ARREADY);
    $display("[%0t] Handshake 2: ARVALID=%b, ARREADY=%b", $time, ARVALID, ARREADY);
    @(posedge clk);
    ARREADY <= 0;

    // @(posedge clk);
    RDATA  <= 32'hABCDEF12;
    RVALID <= 1;

    wait (RREADY);
    @(posedge clk);
    RVALID <= 0;

    ///////////////////////////////////////////////////////////////////////////////////
@(posedge clk);
trigger   <= 1;
src_addr  <= 32'h00000001;  // Offset = 01
length    <= 6'd13;

@(posedge clk);
trigger <= 0;

// ---------- Read 1 ----------
@(posedge clk);
ARREADY <= 1;
wait (ARVALID && ARREADY);
$display("[%0t] Handshake 1", $time);
@(posedge clk);
ARREADY <= 0;
RDATA   <= 32'hA1B2C3D4;  // Assume last 3 bytes used (B2C3D4)
RVALID  <= 1;
wait (RREADY);
@(posedge clk);
RVALID  <= 0;
RDATA   <= 32'd0;

// ---------- Read 2 ----------
ARREADY <= 1;
wait (ARVALID && ARREADY);
$display("[%0t] Handshake 2", $time);
@(posedge clk);
ARREADY <= 0;
RDATA   <= 32'h11223344;
RVALID  <= 1;
wait (RREADY);
@(posedge clk);
RVALID <= 0;

// ---------- Read 3 ----------
ARREADY <= 1;
wait (ARVALID && ARREADY);
$display("[%0t] Handshake 3", $time);
@(posedge clk);
ARREADY <= 0;
RDATA   <= 32'h55667788;
RVALID  <= 1;
wait (RREADY);
@(posedge clk);
RVALID <= 0;

// ---------- Read 4 ----------
ARREADY <= 1;
wait (ARVALID && ARREADY);
$display("[%0t] Handshake 4", $time);
@(posedge clk);
ARREADY <= 0;
RDATA   <= 32'h99AA0000; // Only 1 bytes used
RVALID  <= 1;
wait (RREADY);
@(posedge clk);
RVALID <= 0;

////////////////////////////////////////////////////////////////////////////////////
repeat(5) @(posedge clk);
trigger   <= 1;
src_addr  <= 32'h00000000;  // Offset = 01
length    <= 6'd4;

@(posedge clk);
trigger <= 0;

// ---------- Read 1 ----------
@(posedge clk);
ARREADY <= 1;
wait (ARVALID && ARREADY);
$display("[%0t] Handshake 1", $time);
@(posedge clk);
ARREADY <= 0;
RDATA   <= 32'hA1B2C3D4; 
RVALID  <= 1;
wait (RREADY);
@(posedge clk);
RVALID  <= 0;
RDATA   <= 32'd0;
//////////////////////////////////////////////////////////////////////////////////////
repeat(2) @(posedge clk);
trigger   <= 1;
src_addr  <= 32'h00000000;  // Offset = 01
length    <= 6'd6;

@(posedge clk);
trigger <= 0;

// ---------- Read 1 ----------
@(posedge clk);
ARREADY <= 1;
wait (ARVALID && ARREADY);
$display("[%0t] Handshake 1", $time);
@(posedge clk);
ARREADY <= 0;
RDATA   <= 32'h12345678; 
RVALID  <= 1;
wait (RREADY);
@(posedge clk);
RVALID  <= 0;
RDATA   <= 32'd0;

// ---------- Read 1 ----------
@(posedge clk);
ARREADY <= 1;
wait (ARVALID && ARREADY);
$display("[%0t] Handshake 1", $time);
@(posedge clk);
ARREADY <= 0;
RDATA   <= 32'hABCDEF12; 
RVALID  <= 1;
wait (RREADY);
@(posedge clk);
RVALID  <= 0;
RDATA   <= 32'd0;
#100 $finish;

end


endmodule