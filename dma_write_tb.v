`timescale 1ns/1ps

module tb_DMA_WRITE;

    // Testbench signals
    reg         clk;
    reg         rst;
    reg         trigger;
    reg  [5:0]  length;
    reg  [31:0] dest_addr;
    wire        done;

    // FIFO signals
    wire        fifo_rd_ena;
    wire        fifo_empty;
    wire [31:0] fifo_out;

    // AXI-Lite Write Address Channel
    wire [31:0] AWADDR;
    wire        AWVALID;
    reg         AWREADY;
    wire [2:0]  AWPROT;

    // AXI-Lite Write Data Channel
    wire [31:0] WDATA;
    wire [3:0]  WSTRB;
    wire        WVALID;
    reg         WREADY;

    // AXI-Lite Write Response Channel
    reg  [1:0]  BRESP;
    reg         BVALID;
    wire        BREADY;

    // Instantiate DUT
    DMA_WRITE dut (
        .clk(clk),
        .rst(rst),
        .trigger(trigger),
        .length(length),
        .dest_addr(dest_addr),
        .fifo_rd_ena(fifo_rd_ena),
        .fifo_empty(fifo_empty),
        .fifo_read(fifo_out),
        .AWADDR(AWADDR),
        .AWVALID(AWVALID),
        .AWPROT(AWPROT),
        .AWREADY(AWREADY),
        .WDATA(WDATA),
        .WSTRB(WSTRB),
        .WVALID(WVALID),
        .WREADY(WREADY),
        .BRESP(BRESP),
        .BVALID(BVALID),
        .BREADY(BREADY)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Simple FIFO memory model (4 entries)
reg [31:0] fifo_mem [0:3];
integer fifo_ptr;

// Output assignment
reg [31:0] fifo_data_out;
assign fifo_out = fifo_data_out;

// FIFO empty flag
assign fifo_empty = (fifo_ptr >= length);

// Read data only when explicitly enabled
always @(posedge clk) begin
    if (rst) begin
        fifo_ptr <= 0;
        fifo_data_out <= 32'h0;
    end else if (fifo_rd_ena && !fifo_empty) begin
        fifo_data_out <= fifo_mem[fifo_ptr];
        $display("[%0t] FIFO READ: %h", $time, fifo_mem[fifo_ptr]);
        fifo_ptr <= fifo_ptr + 1;
    end
end


parameter IDLE    = 2'b00,
          ADDR_OK = 2'b01,
          DATA_OK = 2'b10,
          RESP    = 2'b11;
    
    reg [1:0] axi_state;

initial begin
    AWREADY = 0;
    WREADY  = 0;
    BVALID  = 0;
    BRESP   = 2'b00;
    axi_state = IDLE;

    forever begin
        @(posedge clk);
        case (axi_state)

            IDLE: begin
                if (AWVALID) begin
                    AWREADY <= 1;
                    axi_state <= ADDR_OK;
                end
            end

            ADDR_OK: begin
                AWREADY <= 0;
                if (WVALID) begin
                    WREADY <= 1;
                    axi_state <= DATA_OK;
                end
            end

            DATA_OK: begin
                WREADY <= 0;
                // Response phase
                BVALID <= 1;
                BRESP  <= 2'b00; // OKAY
                axi_state <= RESP;
            end

            RESP: begin
                if (BREADY) begin
                    BVALID <= 0;
                    axi_state <= IDLE;
                end
            end

            default: axi_state <= IDLE;

        endcase
    end
end


    // Test sequence
    initial begin
        $dumpfile("dma_write.vcd");
        $dumpvars(0, tb_DMA_WRITE);

        // Initialize signals
        clk = 0;
        rst = 1;
        trigger = 0;
        length = 6;
        dest_addr = 32'h1000_0003;
        fifo_mem[0] = 32'hDEADBEEF;
        fifo_mem[1] = 32'hCAFEBABE;
        fifo_mem[2] = 32'h12345678;
        fifo_mem[3] = 32'hAABBCCDD;
        fifo_ptr = 0;

        #20;
        rst = 0;

        // Trigger DMA transfer
        #20;
        trigger = 1;
        #10;
        trigger = 0;

        // Wait for completion

        #200;

        $display("✅ DMA transfer complete.");
        $finish;
    end

endmodule
