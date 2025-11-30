`timescale 1ns / 1ps

module dma_controller(
    input wire clk,
    input wire reset,
    input wire trigger,
    input wire [4:0] length,
    input wire [31:0] source_address,
    input wire [31:0] destination_add,
    input wire ARREADY,
    input wire [31:0] RDATA,
    input wire RVALID,
    input wire AWREADY,
    input wire WREADY,
    input wire BVALID,
    output reg done,
    output reg [31:0] ARADDR,
    output reg ARVALID,
    output reg RREADY,
    output reg [31:0] AWADDR,
    output reg AWVALID,
    output reg [31:0] WDATA,
    output reg WVALID,
    output reg BREADY
);

    // Read FSM states
    localparam READ_IDLE = 2'b00;
    localparam READ_INIT = 2'b01;
    localparam READ_WAIT = 2'b10;
    localparam READ_DATA = 2'b11;

    // Write FSM states
    localparam WRITE_IDLE = 3'b000;
    localparam WRITE_WAIT = 3'b001;
    localparam WRITE_DATA = 3'b010;
    localparam WRITE_AW_HANDSHAKE = 3'b011;
    localparam WRITE_W_HANDSHAKE = 3'b100;
    localparam WRITE_RESP = 3'b101;

    reg [1:0] read_state;
    reg [2:0] write_state;
    reg [4:0] read_count, write_count;
    reg [31:0] current_read_addr, current_write_addr;

    // FIFO signals
    reg fifo_write_en, fifo_read_en;
    wire fifo_full, fifo_empty;
    wire [31:0] fifo_read_data;
    reg [31:0] fifo_write_data;

    wire read_done, write_done;
    
    sync_fifo fifo (
        .clk(clk),
        .reset(reset),
        .FIFO_RD_EN(fifo_read_en),
        .FIFO_WR_EN(fifo_write_en),
        .write_data(fifo_write_data),
        .read_data(fifo_read_data),
        .FIFO_FULL(fifo_full),
        .FIFO_EMPTY(fifo_empty)
    );
    
    assign read_done = (read_count == length/4) && !(length == 0);
    assign write_done = (write_count == length/4) && !(length == 0);
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            done <= 0;
        end
        else begin
            done <= read_done && write_done;
        end
    end    
    
    // Read FSM
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            read_state <= READ_IDLE;
            read_count <= 0;
            
            ARADDR <= 0;
            ARVALID <= 0;
            RREADY <= 1;
            fifo_write_en <= 0;
    
        end else begin
            case (read_state)
                READ_IDLE: begin
                    ARADDR <= 0;
                    ARVALID <= 0;
                    if (trigger) begin
                        read_count <= 0;
                        current_read_addr <= source_address;
                        read_state <= READ_INIT;
                    end    
                end

                READ_INIT: begin
                    fifo_write_en <= 0;
                    if (read_count == length/4) begin    
                        read_state <= READ_IDLE;
                    end
                    else if (!fifo_full) begin
                        ARADDR <= current_read_addr;
                        ARVALID <= 1;
                        read_state <= READ_WAIT;
                    end
                end
                
                READ_WAIT: begin
                    if (ARREADY && ARVALID) begin
                        ARVALID <= 0;
                        read_state <= READ_DATA;
                    end
                end

                READ_DATA: begin
                    if (RVALID && RREADY) begin
                        fifo_write_en <= 1;
                        fifo_write_data <= RDATA;
                        read_count <= read_count + 1;
                        current_read_addr <= current_read_addr + 4;                 
                        read_state <= READ_INIT;
                    end    
                end                      
                default: read_state <= READ_IDLE;
            endcase
        end
    end

// Write FSM
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            write_state <= WRITE_IDLE;
            write_count <= 0;
            
            AWADDR <= 32'b0;            
            WDATA <= 32'b0;            
            AWVALID <= 0;
            WVALID <= 0;
            BREADY <= 1;
            fifo_read_en <= 0;
        end 
        else begin
            case (write_state)
                WRITE_IDLE: begin
                    AWADDR <= 32'b0;
                    WDATA <= 32'b0;
                    AWVALID <= 0;
                    WVALID <= 0;
                    if(!fifo_empty) begin
                        write_count <= 0;
                        current_write_addr <= destination_add;
                        fifo_read_en <= 1;
                        write_state <= WRITE_WAIT;
                    end
                end
                
                WRITE_WAIT: begin
                    fifo_read_en <= 0;
                    if (write_count == length/4) begin   
                        write_state <= WRITE_IDLE;
                    end    
                    else begin
                        write_state <= WRITE_DATA;
                    end
                end
            
                WRITE_DATA: begin
                        AWADDR <= current_write_addr;
                        AWVALID <= 1;
                        WDATA <= fifo_read_data;
                        WVALID <= 1;
                        write_state <= WRITE_AW_HANDSHAKE;
                end
            
                WRITE_AW_HANDSHAKE: begin
                    if(AWVALID && AWREADY) begin
                        AWVALID <= 0;
                        write_state <= WRITE_W_HANDSHAKE;
                    end
                end
                
                WRITE_W_HANDSHAKE: begin
                    if(WVALID && WREADY) begin
                        WVALID <= 0;
                        write_state <= WRITE_RESP;
                    end
                end
            
            
                WRITE_RESP: begin
                    if(BVALID && BREADY) begin
                        fifo_read_en <= 1;
                        write_count <= write_count + 1;
                        current_write_addr <= current_write_addr + 4;
                        write_state <= WRITE_WAIT;
                    end
                end
      
                default: write_state <= WRITE_WAIT;
            endcase 
        end
    end
endmodule  