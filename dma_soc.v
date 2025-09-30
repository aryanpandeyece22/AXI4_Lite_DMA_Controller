module DMA_SOC(
    // ports from testbench
    input clk, rst,  
    input trigger, 
    input [31:0] src_addr, dest_addr,
    input [5:0] length,
    output done
);

// connecting wires // 

// AXI Read Data Channel
wire [31:0] RDATA;
wire [1:0]  RRESP;
wire        RVALID;
wire        RREADY;

// AXI Read Address Channel
wire [31:0] ARADDR;
wire        ARVALID;
wire [2:0]  ARPROT;
wire        ARREADY;

// AXI Write Address Channel
wire [31:0] AWADDR;
wire        AWVALID;
wire [2:0]  AWPROT;
wire        AWREADY;

// AXI Write Data Channel
wire [31:0] WDATA;
wire [3:0]  WSTRB;
wire        WVALID;
wire        WREADY;

// AXI Write Response Channel
wire  [1:0]  BRESP;
wire         BVALID;
wire         BREADY;

// FIFO interface
wire        fifo_wr_ena;
wire [31:0] fifo_write;
wire        fifo_rd_ena;
wire        fifo_empty;
wire [31:0] fifo_read;

// read source
READ_SRC u_read_src (
    .clk     (clk),
    .rst     (rst),
    .RDATA   (RDATA),
    .RRESP   (RRESP),
    .RVALID  (RVALID),
    .RREADY  (RREADY),
    .ARADDR  (ARADDR),
    .ARVALID (ARVALID),
    .ARPROT  (ARPROT),
    .ARREADY (ARREADY)
);
// read dealigner
DMA_READ u_dma_read (
    .clk        (clk),
    .rst        (rst),
    .trigger    (trigger),
    .length     (length),
    .src_addr   (src_addr),
    .dest_addr  (dest_addr),

    .RDATA      (RDATA),
    .RRESP      (RRESP),
    .RVALID     (RVALID),
    .RREADY     (RREADY),

    .ARADDR     (ARADDR),
    .ARVALID    (ARVALID),
    .ARPROT     (ARPROT),
    .ARREADY    (ARREADY),

    .fifo_wr_ena(fifo_wr_ena),
    .fifo_in    (fifo_write)
);
// fifo 
FIFO u_fifo (
    .clk     (clk),
    .rst     (rst),
    .wr_ena  (fifo_wr_ena),
    .rd_ena  (fifo_rd_ena),
    .wr_data (fifo_write),
    .rd_data (fifo_read),
    .empty   (fifo_empty)
);
// write aligner 
DMA_WRITE u_dma_write (
    .clk        (clk),
    .rst        (rst),
    .trigger    (trigger),
    .length     (length),
    .dest_addr  (dest_addr),
    .done       (done),

    .fifo_rd_ena(fifo_rd_ena),
    .fifo_empty (fifo_empty),
    .fifo_read  (fifo_read),

    .AWADDR     (AWADDR),
    .AWVALID    (AWVALID),
    .AWPROT     (AWPROT),
    .AWREADY    (AWREADY),

    .WDATA      (WDATA),
    .WSTRB      (WSTRB),
    .WVALID     (WVALID),
    .WREADY     (WREADY),

    .BRESP      (BRESP),
    .BVALID     (BVALID),
    .BREADY     (BREADY)
);
// write source 
WRITE_SRC u_write_src (
    .clk     (clk),
    .rst     (rst),
    .AWADDR  (AWADDR),
    .AWVALID (AWVALID),
    .AWPROT  (AWPROT),
    .AWREADY (AWREADY),
    .WDATA   (WDATA),
    .WSTRB   (WSTRB),
    .WVALID  (WVALID),
    .WREADY  (WREADY),
    .BRESP   (BRESP),
    .BVALID  (BVALID),
    .BREADY  (BREADY)
);

endmodule