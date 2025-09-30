module FIFO #(
    parameter DATAWIDTH  = 32,
    parameter FIFO_DEPTH = 16,
    parameter ADDR_WIDTH = $clog2(FIFO_DEPTH)
)(
    input  wire                    clk,
    input  wire                    rst,                    
    input  wire                    wr_ena,
    input  wire                    rd_ena,
    input  wire [DATAWIDTH-1:0]    wr_data,
    output reg  [DATAWIDTH-1:0]    rd_data,
    output wire                    full,
    output wire                    empty
);

    // Memory and pointers
    reg [DATAWIDTH-1:0] mem [0:FIFO_DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr = 0;
    reg [ADDR_WIDTH-1:0] rd_ptr = 0;
    reg [ADDR_WIDTH:0]   count  = 0;

    // Write Logic
    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= 0;
        end else if (wr_ena && !full) begin
            mem[wr_ptr] <= wr_data;
            wr_ptr <= wr_ptr + 1;
        end
    end

    // Read Logic
    always @(posedge clk) begin
        if (rst) begin
            rd_ptr <= 0;
            rd_data <= 0;
        end else if (rd_ena && !empty) begin
            rd_data <= mem[rd_ptr];
            rd_ptr <= rd_ptr + 1;
        end
    end

    // Counter Management
    always @(posedge clk) begin
        if (rst) begin
            count <= 0;
        end else begin
            case ({wr_ena && !full, rd_ena && !empty})
                2'b10: count <= count + 1; // write only
                2'b01: count <= count - 1; // read only
                default: count <= count;   // no change or simultaneous
            endcase
        end
    end

    // Status Flags
    assign full  = (count == FIFO_DEPTH);
    assign empty = (count == 0);

endmodule
