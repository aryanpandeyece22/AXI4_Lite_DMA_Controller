module DMA_READ (
    // generic control signals 
    input clk, rst,

    // processor signals 
    input          trigger,
    input [5 : 0]  length, // only 32 bytes can be transfered at once
    input [31: 0]  src_addr, dest_addr,
    output         done,

    
    // R - read data 
    input [31:0] RDATA,
    input [1:0]           RRESP,
    input                 RVALID,
    output reg            RREADY, 

    // AR - read address 
    output reg [31:0] ARADDR, 
    output reg                 ARVALID,
    output reg [2:0]           ARPROT,   //for future use
    input                      ARREADY,


    // writing into buffer 
    output reg fifo_wr_ena,
    output [31:0] fifo_in
);

// read alligner // 
// parameters // 
reg [1:0] READ_STATE;
parameter READ_IDLE  = 2'b00;
parameter READ_ADDR  = 2'b01;
parameter READ_DATA  = 2'b10;
parameter READ_FIN   = 2'b11;
// aligner state // 
reg [1:0] ALIGNER_STATE;
parameter ALIGNER_FIRST  = 2'b01;
parameter ALIGNER_SECOND = 2'b10;
parameter ALIGNER_THIRD  = 2'b11;
parameter ALIGNER_IDLE   = 2'b00;

//variables
reg align;
reg [5:0]  a_len;
reg [31:0] a_base_addr;
reg [31:0] a_buffer_1, a_buffer_2;
reg [1:0]  a_offset;
reg READ_DONE;

//signal for edge cases 
reg fin_aligner;

// write into fifo 
assign fifo_in = a_buffer_2;

wire [1:0] inv_offset;
assign inv_offset = ~src_addr[1:0];

// Data shifting logic
reg [31:0] shifted_data, combined_data;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        shifted_data  <= 32'd0;
        combined_data <= 32'd0;
    end else if ((RREADY && RVALID)) begin
        case (a_offset)
            2'b00: begin
                shifted_data  <= RDATA;
                combined_data <= a_buffer_1;
            end
            2'b01: begin
                shifted_data  <= {8'd0,  RDATA[31:8]};
                combined_data <= {RDATA[7:0],  a_buffer_1[23:0]};
            end
            2'b10: begin
                shifted_data  <= {16'd0, RDATA[31:16]};
                combined_data <= {RDATA[15:0], a_buffer_1[15:0]};
            end
            2'b11: begin
                shifted_data  <= {24'd0, RDATA[31:24]};
                combined_data <= {RDATA[23:0], a_buffer_1[7:0]};
            end
        endcase
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        a_buffer_1    <= 32'd0;
        a_buffer_2    <= 32'd0;
        fifo_wr_ena   <= 1'b0;
        fin_aligner   <= 1'b0;
        a_len         <= 6'd0;
        ALIGNER_STATE <= ALIGNER_IDLE;
    end else begin
        case (ALIGNER_STATE) 
            ALIGNER_IDLE: begin
                fifo_wr_ena <= 1'b0;
                align       <= 1'b0;
                if (trigger) begin
                    ALIGNER_STATE <= ALIGNER_FIRST;
                    // data length after next cycle 
                    a_len <= length - {4'd0, inv_offset} - 6'd1;
                end
            end
            ALIGNER_FIRST: begin

                if (align) begin
                    a_buffer_1 <= shifted_data;
                    a_buffer_2 <= shifted_data;
                    align      <= 1'b0;

                    // changing the state // 
                    if (a_len==6'd0) begin
                        fifo_wr_ena <= 1;
                        ALIGNER_STATE <= ALIGNER_IDLE;
                    end else if (a_len>6'd4) begin
                        a_len         <= a_len - 6'd4;
                        ALIGNER_STATE <= ALIGNER_SECOND;
                    end else begin
                        a_len         <= 6'd0;
                        if (a_len > {4'd0, a_offset})
                            fin_aligner <= 1;
                        ALIGNER_STATE <= ALIGNER_SECOND;
                    end 
                end else 
                    fifo_wr_ena   <= 1'b0;
            end
            ALIGNER_SECOND: begin
                if (align) begin
                    a_buffer_1  <= shifted_data;
                    a_buffer_2  <= combined_data;
                    fifo_wr_ena <= 1'b1;
                    align       <= 1'b0;

                    // changing the state // 
                    if (a_len==6'd0) begin
                        if (!fin_aligner)
                            ALIGNER_STATE <= ALIGNER_IDLE;
                        else 
                            ALIGNER_STATE <= ALIGNER_THIRD;
                    end else if (a_len>6'd4) begin
                        a_len         <= a_len - 6'd4;
                        ALIGNER_STATE <= ALIGNER_SECOND;
                    end else begin
                        a_len         <= 6'd0;
                        if (a_len > {4'd0, a_offset})
                            fin_aligner <= 1;
                        ALIGNER_STATE <= ALIGNER_SECOND;
                    end 
                end else begin
                    fifo_wr_ena <= 1'b0;
                end
            end
            ALIGNER_THIRD: begin
                    a_buffer_2  <= shifted_data;
                    fifo_wr_ena <= 1;  
                    fin_aligner <= 0;
                    ALIGNER_STATE <= ALIGNER_IDLE;
            end
        endcase
    end
end


reg [5:0] r_len;
reg r_first;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        a_base_addr <= 32'd0;
        a_offset    <= 2'd0;
        ARVALID     <= 1'd0;
        RREADY      <= 1'd0;
        READ_DONE   <= 1'd0;
        READ_STATE  <= 2'd0;
        r_first     <= 1'b0;
        r_len       <= 1'b0;
        align       <= 1'b0;
    end else begin

    case (READ_STATE)
        READ_IDLE: begin
            if (trigger) begin
                // capture base addr and all 
                a_base_addr <= {src_addr[31:2], 2'b00};
                a_offset    <= src_addr[1:0]; 
                READ_STATE  <= READ_ADDR;
                r_len       <= length;
                r_first     <= 1;
            end
        end 
        READ_ADDR: begin
            if (!ARVALID) begin
                ARADDR  <= a_base_addr;
                ARVALID <= 1'b1;
            end
            else if (ARREADY) begin
                READ_STATE  <= READ_DATA;
                ARVALID     <= 1'b0;
                RREADY      <= 1'b1;
                a_base_addr <= a_base_addr + 32'd4;
                r_first     <= 0;
                if (r_first)
                    r_len <= r_len - {4'd0, ~a_offset} - 6'd1;
                else if(r_len>=6'd4)
                    r_len <= r_len - 6'd4;
                else 
                    r_len <= 6'd0;
            end 
        end
        READ_DATA: begin
            // read data once
            if (RREADY && RVALID) begin
                // data gets captured in a_buffer_1
                RREADY     <= 1'd0;
                READ_STATE <= READ_ADDR;
                align      <= 1'b1;
                if (r_len==6'd0) READ_STATE <= READ_IDLE;
                else begin
                    // push data early on 
                    ARADDR  <= a_base_addr;
                    ARVALID <= 1'b1;
                    READ_STATE <= READ_ADDR;
                end
            end
        end
    endcase

    end
end

endmodule
