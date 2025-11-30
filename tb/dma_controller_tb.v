`timescale 1ns / 1ps

module dma_controller_tb;

    // Clock and reset
    reg clk;
    reg reset;
    
    // DMA controller inputs
    reg trigger;
    reg [4:0] length;
    reg [31:0] source_address;
    reg [31:0] destination_add;
    
    // DMA controller outputs
    wire done;
    
    // AXI-Lite interface signals
    wire [31:0] ARADDR, AWADDR, RDATA, WDATA;
    wire ARVALID, AWVALID, RREADY, WVALID, BREADY;
    wire ARREADY, AWREADY, RVALID, WREADY, BVALID;

    // Instantiate DMA controller
    dma_controller dut (
        .clk(clk),
        .reset(reset),
        .trigger(trigger),
        .length(length),
        .source_address(source_address),
        .destination_add(destination_add),
        .ARREADY(ARREADY),
        .RDATA(RDATA),
        .RVALID(RVALID),
        .AWREADY(AWREADY),
        .WREADY(WREADY),
        .BVALID(BVALID),
        .done(done),
        .ARADDR(ARADDR),
        .ARVALID(ARVALID),
        .RREADY(RREADY),
        .AWADDR(AWADDR),
        .AWVALID(AWVALID),
        .WDATA(WDATA),
        .WVALID(WVALID),
        .BREADY(BREADY)
    );

    // Instantiate slave testbench
        testbench_slave slave (
        .clk(clk),
        .reset(reset),
        .AWADDR(AWADDR),
        .AWVALID(AWVALID),
        .AWREADY(AWREADY),
        .WDATA(WDATA),
        .WVALID(WVALID),
        .WREADY(WREADY),
        .BVALID(BVALID),
        .BREADY(BREADY),
        .ARADDR(ARADDR),
        .ARVALID(ARVALID),
        .ARREADY(ARREADY),
        .RDATA(RDATA),
        .RVALID(RVALID),
        .RREADY(RREADY)
    );
    
    // Clock generation
    always #5 clk = ~clk;

    // Test sequence
    initial begin
    
        // Initialize signals
        clk = 0;
        reset = 1;
        trigger = 0;
        length = 0;
        source_address = 0;
        destination_add = 0;

        // Reset sequence
        #20 reset = 0;

//         Test case 1: Simple transfer (4 bytes)
        #10 source_address = 32'h1000;  // Aligned to 4 bytes
            destination_add = 32'h2000; // Aligned to 4 bytes
            length = 5'h04;             // Multiple of 4 bytes
            trigger = 1;                // Trigger DMA operation
            #10 trigger = 0;            // Deassert trigger after one clock cycle
            wait(done);                 // Wait for operation to complete

        // Test case 2: Maximum transfer (28 bytes)
        #20 source_address = 32'h1100;  // Aligned to 4 bytes
            destination_add = 32'h2100; // Aligned to 4 bytes
            length = 5'h1C;             // Multiple of 4 bytes (28 bytes)
            trigger = 1;                // Trigger DMA operation
            #10 trigger = 0;            // Deassert trigger after one clock cycle
            wait(done);                 // Wait for operation to complete

//         Test case 3: Back-to-back transfers with valid alignment
        #20 source_address = 32'h1200;   // Aligned to 4 bytes
            destination_add = 32'h2200;  // Aligned to 4 bytes
            length = 5'h08;              // Multiple of 4 bytes (8 bytes)
            trigger = 1;                 // Trigger DMA operation
            #10 trigger = 0;             // Deassert trigger after one clock cycle
            wait(done);                  // Wait for operation to complete

            #10 source_address = 32'h1300;   // Aligned to 4 bytes
                destination_add = 32'h2300;   // Aligned to 4 bytes
                length = 5'h10;               // Multiple of 4 bytes (16 bytes)
                trigger = 1;                  // Trigger DMA operation
                #10 trigger = 0;              // Deassert trigger after one clock cycle
                wait(done);                   // Wait for operation to complete

        // End simulation after all test cases are executed
        #100 $finish;
    end
endmodule