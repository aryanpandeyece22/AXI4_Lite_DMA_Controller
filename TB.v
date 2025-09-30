`timescale 1ns/1ps

module testbench;

// control signals 
reg clk, rst, trigger;
wire done;
reg [31:0] src_addr,dest_addr;
reg [5:0] length;

DMA_SOC dut(
    .clk(clk),
    .rst(rst),
    .trigger(trigger),
    .src_addr(src_addr),
    .dest_addr(dest_addr),
    .length(length),
    .done(done)
);

always #5 clk = ~clk;

initial begin
    $dumpfile("dma_dump.vcd");
    $dumpvars(0,testbench);

    clk = 1;
    rst = 1;
    trigger = 0;
    src_addr = 0;
    dest_addr = 0;
    length = 0;
    repeat (3) @(posedge clk);
    rst = 0;
    
    // trigger transaction 
    @(negedge clk);
    trigger = 1;
    src_addr = 32'h3;
    dest_addr = 32'h3;
    length = 6'd6;
    @(negedge clk);
    trigger = 0;

    #500 $finish;
    
end 

endmodule