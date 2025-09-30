module DMA_WRITE (
    // generic control signals 
    input clk, rst,

    // processor signals 
    input          trigger,
    input [5 : 0]  length, // only 32 bytes can be transfered at once
    input [31: 0]  dest_addr,
    output reg done,


    // writing into buffer 
    output reg fifo_rd_ena,
    input fifo_empty,
    input [31:0] fifo_read,

    // AW - write address channel 
    output  reg [31:0] AWADDR,
    output  reg                 AWVALID, 
    output  reg [2:0]           AWPROT,  //for future use 
    input                       AWREADY,

    // W - write data channel 
    output reg [31:0] WDATA,
    output reg [3:0]           WSTRB,
    output reg                 WVALID,
    input                      WREADY,

    // B - Write response 
    input  [1:0]    BRESP,
    input           BVALID,
    output reg      BREADY

);

    // Internal registers and wires
    reg [1:0]  DEALIGNER_STATE;
    reg [31:0] base_addr;
    reg [5:0]  d_len;
    reg [1:0]  d_offset;
    reg [31:0] d_buffer;
    reg        d_start;
    reg [1:0]  WRITE_STATE;

    // Data alignment helpers
    wire [31:0] shifted_data;
    wire [31:0] combined_data;

assign shifted_data  = (d_offset==2'b00) ? 32'd0 :
                      (d_offset==2'b01)  ? {24'd0, fifo_read[31:24]}:
                      (d_offset==2'b10)  ? {16'd0, fifo_read[31:16]}:
                                           {8'd0 , fifo_read[31:08]};
assign combined_data = (d_offset==2'b00) ? fifo_read :
                      (d_offset==2'b01)  ? {fifo_read[23:00], d_buffer[07:00]}:
                      (d_offset==2'b10)  ? {fifo_read[15:00], d_buffer[15:00]}:
                                           {fifo_read[07:00], d_buffer[23:00]};

// dealigner stage
parameter DEALIGNER_IDLE   = 2'b00;
parameter DEALIGNER_FIRST  = 2'b01;
parameter DEALINGER_SECOND = 2'b10;

// dealigner logic // 
always @(posedge clk or posedge rst) begin
    if (rst) begin
            DEALIGNER_STATE <= DEALIGNER_IDLE;
            base_addr       <= 32'd0;
            d_len           <= 6'd0;
            d_offset        <= 2'd0;
            d_buffer        <= 32'd0;
            fifo_rd_ena     <= 1'b0;
            d_start         <= 1'b0;
    end else begin
        case (DEALIGNER_STATE)
            // wait for trigger signal 
            DEALIGNER_IDLE: begin
                done <= 0;
                if (trigger) begin
                    base_addr  <= {dest_addr[31:2],2'b00};
                    d_len      <= length; 
                    d_offset   <= dest_addr[1:0];
                    DEALIGNER_STATE <= DEALIGNER_FIRST;
                end 
            end
            // first data entry
            DEALIGNER_FIRST: begin
                // fetch data 
                if (!fifo_rd_ena && !fifo_empty) begin
                    fifo_rd_ena <= 1;
                end
                if (fifo_rd_ena) begin
                    fifo_rd_ena <= 0;
                    d_start     <= 1;
                end
                if (d_start) begin
                    d_start     <= 0;
                    d_buffer    <= shifted_data;
                    // data //
                    WDATA       <= combined_data;
                    WVALID      <= 1;
                    // address // 
                    AWADDR      <= base_addr;
                    AWVALID     <= 1;
                    // WSTRB // 
                    if (d_len > ({4'd0, ~d_offset}+6'd1))
                        WSTRB <= 4'b1111 << d_offset;
                    else 
                        WSTRB <= ((1 << d_len) - 1) << d_offset;
                    // change state // 
                    base_addr       <= base_addr + 6'd4;
                    d_len           <= d_len - {4'd0, ~d_offset} - 6'd1;
                    DEALIGNER_STATE <= DEALINGER_SECOND;
                end
            end
            // continution 
            DEALINGER_SECOND: begin
                // handling last data transfer // 
                if (d_len <= 6'd0) begin
                    done            <= 1;
                    DEALIGNER_STATE <= DEALIGNER_IDLE;
                end
                else if ((d_len <= {4'd0,d_offset})) begin
                    if (WRITE_STATE==W_IDLE && !WVALID) begin
                        // data // 
                        WDATA  <= d_buffer;
                        WVALID <= 1;
                        // address //
                        AWADDR  <= base_addr;
                        AWVALID <= 1;
                        // WSTRB // 
                        WSTRB <= ((1 << d_len) - 1);
                        // length // 
                        d_len <= 6'd0;
                    end
                end else begin
                    // fetch word // 
                    if (!fifo_rd_ena && !fifo_empty) begin
                        fifo_rd_ena <= 1;
                    end 
                    if (fifo_rd_ena) begin
                        fifo_rd_ena <= 0;
                        d_start     <= 1;
                    end
                    // align word // 
                    if (d_start) begin
                        if (WRITE_STATE==W_IDLE && !WVALID) begin
                            d_start     <= 0;
                            d_buffer    <= shifted_data;
                            // data //
                            WDATA       <= combined_data;
                            WVALID      <= 1;
                            // address // 
                            AWADDR      <= base_addr;
                            AWVALID     <= 1;
                            // change state // 
                            base_addr       <= base_addr + 6'd4;
                            // change in length // 
                            if (d_len > 6'd4) begin
                                d_len <= d_len - 6'd4;
                                WSTRB <= 4'b1111;
                            end
                            else begin
                                d_len <= 6'd0;
                                WSTRB <= ((1 << d_len) - 1);
                            end
                                
                        end
                    end
                end
            end

        endcase
    end
end

// Write logic //
// state machine parameters 
parameter W_IDLE = 2'b00;
parameter W_SEND = 2'b01;
parameter W_RESP = 2'B10;
reg       [1:0] response;

always @(posedge clk or posedge rst) begin

    if (rst) begin
        AWADDR  <= 32'd0;
        AWVALID <= 1'd0;
        WDATA   <= 32'd0;
        WSTRB   <= 4'd0;
        WVALID  <= 1'd0;
        BREADY  <= 1'b0;
        WRITE_STATE <= 2'd0;
    end else begin
        case (WRITE_STATE)
            W_IDLE: begin
                // AWVALID and WVALID is set in dma controller. 
                if (AWVALID & WVALID)  // assuming both of them to go up at once
                    WRITE_STATE <= W_SEND; // as soon as it starts the transaction change to send mode.
            end
            W_SEND: begin
                if (AWREADY) AWVALID <= 0;
                if (WREADY)  WVALID  <= 0;

                if (!WVALID & !AWVALID) begin
                    WRITE_STATE <= W_RESP;
                    BREADY      <= 1'b1;
                end
            end
            W_RESP: begin
                if (BREADY & BVALID) begin
                    response <= BRESP;
                    BREADY   <= 1'b0;
                    WRITE_STATE <= W_IDLE;
                end
            end
            default begin
                BREADY  <= 1'b0;
                WRITE_STATE <= W_IDLE; 
            end
        endcase
    end
    
end

endmodule





// // endmodule
// module DMA_WRITE (
//     input         clk, rst,

//     // processor signals 
//     input         trigger,
//     input  [5:0]  length, // only 32 bytes can be transferred at once
//     input  [31:0] dest_addr,
//     output reg    done,

//     // writing into buffer 
//     output reg    fifo_rd_ena,
//     input         fifo_empty,
//     input  [31:0] fifo_out,

//     // AW - write address channel 
//     output reg [31:0] AWADDR,
//     output reg        AWVALID, 
//     output reg [2:0]  AWPROT,  //for future use 
//     input             AWREADY,

//     // W - write data channel 
//     output reg [31:0] WDATA,
//     output reg [3:0]  WSTRB,
//     output reg        WVALID,
//     input             WREADY,

//     // B - Write response 
//     input  [1:0]      BRESP,
//     input             BVALID,
//     output reg        BREADY
// );

//     // Internal registers and wires
//     reg [1:0]  DEALIGNER_STATE;
//     reg [31:0] base_addr;
//     reg [5:0]  d_len;
//     reg [1:0]  d_offset;
//     reg [31:0] d_buffer;
//     reg        d_start;
//     reg [1:0]  WRITE_STATE;
//     reg [1:0]  response;

//     // Data alignment helpers
//     wire [31:0] shifted_data;
//     wire [31:0] combined_data;

//     // Data shifting logic
//     assign shifted_data = (d_offset == 2'b00) ? 32'd0 :
//                           (d_offset == 2'b01) ? {24'd0, fifo_out[31:24]} :
//                           (d_offset == 2'b10) ? {16'd0, fifo_out[31:16]} :
//                           (d_offset == 2'b11) ? {8'd0 , fifo_out[31:8]} : 32'd0;

//     assign combined_data = (d_offset == 2'b00) ? fifo_out :
//                            (d_offset == 2'b01) ? {fifo_out[23:0], d_buffer[7:0]} :
//                            (d_offset == 2'b10) ? {fifo_out[15:0], d_buffer[15:0]} :
//                            (d_offset == 2'b11) ? {fifo_out[7:0], d_buffer[23:0]} : 32'd0;

//     // Dealigner state machine parameters
//     parameter DEALIGNER_IDLE   = 2'b00;
//     parameter DEALIGNER_FIRST  = 2'b01;
//     parameter DEALIGNER_SECOND = 2'b10;

//     // Write state machine parameters 
//     parameter W_IDLE = 2'b00;
//     parameter W_SEND = 2'b01;
//     parameter W_RESP = 2'b10;

//     // Dealigner FSM
//     always @(posedge clk or posedge rst) begin
//         if (rst) begin
//             DEALIGNER_STATE <= DEALIGNER_IDLE;
//             base_addr       <= 32'd0;
//             d_len           <= 6'd0;
//             d_offset        <= 2'd0;
//             d_buffer        <= 32'd0;
//             fifo_rd_ena     <= 1'b0;
//             d_start         <= 1'b0;
//             done            <= 1'b0;
//         end else begin
//             case (DEALIGNER_STATE)
//                 // wait for trigger signal 
//                 DEALIGNER_IDLE: begin
//                     fifo_rd_ena <= 1'b0;
//                     d_start     <= 1'b0;
//                     done        <= 1'b0;
//                     if (trigger) begin
//                         base_addr  <= {dest_addr[31:2],2'b00};
//                         d_len      <= length; 
//                         d_offset   <= dest_addr[1:0];
//                         DEALIGNER_STATE <= DEALIGNER_FIRST;
//                     end 
//                 end
//                 // first data entry
//                 DEALIGNER_FIRST: begin
//                     // fetch data 
//                     if (!fifo_rd_ena && !fifo_empty) begin
//                         fifo_rd_ena <= 1'b1;
//                     end 
//                     if (fifo_rd_ena) begin
//                         fifo_rd_ena <= 1'b0;
//                         d_buffer    <= shifted_data;
//                         // data //
//                         WDATA       <= combined_data;
//                         WVALID      <= 1'b1;
//                         // address // 
//                         AWADDR      <= base_addr;
//                         AWVALID     <= 1'b1;
//                         AWPROT      <= 3'b000;
//                         // WSTRB // 
//                         if (d_len > ({4'd0, ~d_offset} + 6'd1))
//                             WSTRB <= 4'b1111 << d_offset;
//                         else 
//                             WSTRB <= ((1 << d_len) - 1) << d_offset;
//                         // change state // 
//                         base_addr       <= base_addr + 6'd4;
//                         d_len           <= d_len - {4'd0, ~d_offset} - 6'd1;
//                         DEALIGNER_STATE <= DEALIGNER_SECOND;
//                     end
//                 end
//                 // continuation 
//                 DEALIGNER_SECOND: begin
//                     // handling last data transfer // 
//                     if (d_len <= 6'd0) begin
//                         DEALIGNER_STATE <= DEALIGNER_IDLE;
//                         done            <= 1'b1;
//                     end else if ((d_len <= {4'd0,d_offset})) begin
//                         if (WRITE_STATE == W_IDLE || WRITE_STATE == W_RESP) begin
//                             // data // 
//                             WDATA  <= d_buffer;
//                             WVALID <= 1'b1;
//                             // address //
//                             AWADDR  <= base_addr;
//                             AWVALID <= 1'b1;
//                             AWPROT  <= 3'b000;
//                             // WSTRB // 
//                             WSTRB <= ((1 << d_len) - 1);
//                             // length // 
//                             d_len <= 6'd0;
//                         end
//                     end else begin
//                         // fetch word // 
//                         if (!fifo_rd_ena && !fifo_empty) begin
//                             fifo_rd_ena <= 1'b1;
//                             d_start     <= 1'b1;
//                         end
//                         // align word // 
//                         if (d_start) begin
//                             fifo_rd_ena <= 1'b0;
//                             if (WRITE_STATE == W_IDLE || WRITE_STATE == W_RESP) begin
//                                 d_start     <= 1'b0;
//                                 d_buffer    <= shifted_data;
//                                 // data //
//                                 WDATA       <= combined_data;
//                                 WVALID      <= 1'b1;
//                                 // address // 
//                                 AWADDR      <= base_addr;
//                                 AWVALID     <= 1'b1;
//                                 AWPROT      <= 3'b000;
//                                 // change state // 
//                                 base_addr   <= base_addr + 6'd4;
//                                 // change in length // 
//                                 if (d_len > 6'd4) begin
//                                     d_len <= d_len - 6'd4;
//                                     WSTRB <= 4'b1111;
//                                 end else begin
//                                     d_len <= 6'd0;
//                                     WSTRB <= ((1 << d_len) - 1);
//                                 end
//                             end
//                         end
//                     end
//                 end
//             endcase
//         end
//     end

//     // Write logic - Write FSM
//     always @(posedge clk or posedge rst) begin
//         if (rst) begin
//             AWVALID     <= 1'b0;
//             WVALID      <= 1'b0;
//             BREADY      <= 1'b0;
//             WRITE_STATE <= W_IDLE;
//         end else begin
//             case (WRITE_STATE)
//                 W_IDLE: begin
//                     BREADY <= 1'b0;
//                     if (AWVALID & WVALID)
//                         WRITE_STATE <= W_SEND;
//                 end
//                 W_SEND: begin
//                     if (AWREADY) AWVALID <= 1'b0;
//                     if (WREADY)  WVALID  <= 1'b0;
//                     if (!WVALID & !AWVALID) begin
//                         WRITE_STATE <= W_RESP;
//                         BREADY      <= 1'b1;
//                     end
//                 end
//                 W_RESP: begin
//                     if (BREADY & BVALID) begin
//                         response    <= BRESP;
//                         BREADY      <= 1'b0;
//                         WRITE_STATE <= W_IDLE;
//                     end
//                 end
//                 default: begin
//                     BREADY      <= 1'b0;
//                     WRITE_STATE <= W_IDLE; 
//                 end
//             endcase
//         end
//     end

// endmodule
