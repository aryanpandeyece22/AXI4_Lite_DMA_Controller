`timescale 1ns / 1ps

module sync_fifo (
    input wire clk,
    input wire reset,
    input wire FIFO_WR_EN,
    input wire FIFO_RD_EN,
    input wire [31:0] write_data,
    output reg [31:0] read_data,
    output  FIFO_FULL,
    output FIFO_EMPTY
);

    reg [31:0] memory[0:15];
    reg [3:0] write_ptr;
    reg [3:0] read_ptr;
    reg [3:0] count;
    
    assign FIFO_FULL = (count == 16);
    assign FIFO_EMPTY = (count == 0);
    
    always @(posedge clk or posedge reset) begin
    if (reset) begin
        write_ptr <= 0;
        read_ptr <= 0;
        count <= 0;
    end 
    else begin
        case ({FIFO_WR_EN && !FIFO_FULL, FIFO_RD_EN && !FIFO_EMPTY})
     
            // Only Write operation    
            2'b10: begin
                memory[write_ptr] <= write_data;
                write_ptr <= (write_ptr == 15)? 0:write_ptr + 1;
                count <= count + 1;
            end
            
            // Only Read operation
            2'b01: begin
                read_data <= memory[read_ptr];
                read_ptr <= (read_ptr == 15)? 0:read_ptr + 1;
                count <= count - 1;
            end

            // Simultaneous Read & Write
            2'b11: begin 
                memory[write_ptr] <= write_data;
                write_ptr <= (write_ptr == 15)? 0:write_ptr + 1;
                read_data <= memory[read_ptr];
                read_ptr <= (read_ptr == 15)? 0:read_ptr + 1;
            end

            default: ; 
        endcase
    end
end
endmodule