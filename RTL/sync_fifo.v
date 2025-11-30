module sync_fifo_extra_bit (
    input  wire        clk,
    input  wire        reset,

    input  wire        FIFO_WR_EN,
    input  wire        FIFO_RD_EN,

    input  wire [31:0] write_data,
    output reg  [31:0] read_data,

    output wire        FIFO_FULL,
    output wire        FIFO_EMPTY
);

    // ------------------------------------------------------------------------
    // FIFO parameters
    // ------------------------------------------------------------------------
    localparam DEPTH      = 16;
    localparam ADDR_WIDTH = 4;           // 16 entries → 4 bits
    localparam PTR_WIDTH  = ADDR_WIDTH + 1; // +1 extra MSB

    // ------------------------------------------------------------------------
    // FIFO memory array
    // ------------------------------------------------------------------------
    reg [31:0] mem [0:DEPTH-1];

    // ------------------------------------------------------------------------
    // Read and write pointers (with extra MSB)
    // ------------------------------------------------------------------------
    reg [PTR_WIDTH-1:0] wr_ptr;   // 5 bits: {MSB, 4-bit address}
    reg [PTR_WIDTH-1:0] rd_ptr;

    wire [ADDR_WIDTH-1:0] wr_addr = wr_ptr[ADDR_WIDTH-1:0];
    wire [ADDR_WIDTH-1:0] rd_addr = rd_ptr[ADDR_WIDTH-1:0];

    // ------------------------------------------------------------------------
    // FIFO EMPTY condition
    // ------------------------------------------------------------------------
    assign FIFO_EMPTY = (wr_ptr == rd_ptr);

    // ------------------------------------------------------------------------
    // FIFO FULL condition
    // FULL when:
    //   - lower bits are equal (same index)
    //   - MSBs are opposite (write wrapped around once more than read)
    // ------------------------------------------------------------------------
    assign FIFO_FULL =
        (wr_addr == rd_addr) && (wr_ptr[PTR_WIDTH-1] != rd_ptr[PTR_WIDTH-1]);

    // ------------------------------------------------------------------------
    // Write Logic
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            wr_ptr <= 0;
        end else begin
            if (FIFO_WR_EN && !FIFO_FULL) begin
                mem[wr_addr] <= write_data;
                wr_ptr <= wr_ptr + 1;       // increments MSB automatically on wrap
            end
        end
    end

    // ------------------------------------------------------------------------
    // Read Logic
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rd_ptr <= 0;
            read_data <= 0;
        end else begin
            if (FIFO_RD_EN && !FIFO_EMPTY) begin
                read_data <= mem[rd_addr];
                rd_ptr <= rd_ptr + 1;       // increments MSB automatically on wrap
            end
        end
    end

endmodule
