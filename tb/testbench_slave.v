`timescale 1ns / 1ps

module testbench_slave (
    input wire clk,
    input wire reset,

    input wire [31:0] AWADDR,
    input wire AWVALID,
    output reg AWREADY,

    input wire [31:0] WDATA,
    input wire WVALID,
    output reg WREADY,

    output reg BVALID,
    input wire BREADY,

    input wire [31:0] ARADDR,
    input wire ARVALID,
    output reg ARREADY,

    output reg [31:0] RDATA,
    output reg RVALID,
    input wire RREADY
);

    reg [31:0] memory[0:4876];
    reg [31:0] write_address;
    reg [31:0] read_address;

    integer i;
    initial begin
        for (i = 0; i < 4876; i = i + 1)
            memory[i] = 0;

        memory[32'h1000] = 32'hAABBCCDD;
        
        memory[32'h1100] = 32'h11223344;
        memory[32'h1104] = 32'h55667788;
        memory[32'h1108] = 32'hAAAAAAAA;
        memory[32'h110C] = 32'hBBBBBBBB;
        memory[32'h1110] = 32'hCCCCCCCC;
        memory[32'h1114] = 32'hDDDDDDDD;
        memory[32'h1118] = 32'hEEEEEEEE;

        memory[32'h1200] = 32'h11111111;
        memory[32'h1204] = 32'h22222222;
        memory[32'h1300] = 32'h44444444;
        memory[32'h1304] = 32'h55555555;
        memory[32'h1308] = 32'h66666666;
        memory[32'h130C] = 32'h88888888;
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            AWREADY <= 'b0;
            write_address <= 'b0;
        end else begin
            if (AWVALID && !AWREADY) begin
                AWREADY <= 'b1;
                write_address <= AWADDR;
            end else begin
                AWREADY <= 'b0;
            end 
        end 
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            WREADY <= 'b0;
            BVALID <= 'b0;
        end else begin
            if (WVALID && !WREADY && !AWVALID) begin
                WREADY <= 'b1;
                memory[write_address] <= WDATA;
            end else begin
                WREADY <= 'b0;
            end

            if (WVALID && WREADY && !BVALID) begin
                BVALID <= 'b1;
            end else if (BVALID && BREADY) begin
                BVALID <= 'b0;
            end 
        end 
    end

    always @(posedge clk or posedge reset) begin  
       if(reset) begin  
           ARREADY <= 'b0;  
           read_address <= 'b0;  
       end else begin  
           if(ARVALID && !ARREADY) begin  
               ARREADY <= 'b1;
               read_address <= ARADDR;
           end else   
               ARREADY <= 'b0;  
       end  
    end  

    always @(posedge clk or posedge reset) begin  
       if(reset) begin  
           RDATA <= 'b0;  
           RVALID <= 'b0;  
       end else begin  
           if(ARVALID && ARREADY && !RVALID) begin  
               RDATA <= memory[read_address]; 
               RVALID <= 'b1;   
           end else if(RVALID && RREADY)   
               RVALID <= 'b0;   
       end  
    end  

endmodule 