module READ_SRC #(
    parameter DATAWIDTH = 32
) (
    //generic control signals 
    input clk, rst,

    // R - read data 
    output reg [DATAWIDTH-1:0] RDATA,
    output reg [1:0]           RRESP,   
    output reg                 RVALID,
    input                      RREADY, 

    // AR - read address 
    input [DATAWIDTH-1:0] ARADDR, 
    input                 ARVALID,
    input [2:0]           ARPROT,
    output reg            ARREADY

);
// word(32 bits) -> [(byte)(byte)(byte)(byte)] //  byte is 8 bits
reg [DATAWIDTH-1 : 0] RAM [DATAWIDTH-1 : 0]; 
// data to be transfered and recieved in bytes 
initial begin
    RAM[1] = 32'h11223344;
    RAM[2] = 32'h12345678;
    RAM[3] = 32'h9ABCDE12;
    RAM[4] = 32'h3456789A;
end
// Read from RAM 
parameter LEN = $clog2(DATAWIDTH); // bit length of data addr // 
reg  [DATAWIDTH-1 : 0] rd_addr, rd_data;
reg  [LEN-1       : 0] addr;

// input memory addr will always be multiple of 4 here 
always @(*) begin
    addr  = rd_addr[6:2];
end

// assign value of rd_data at posedge clk
always @(*) begin
    rd_data = RAM[addr];
end

// read transaction 
// state machine parameters 
parameter IDLE      = 2'b00;
parameter READ_ADDR = 2'b01; 
parameter READ_DATA = 2'b10;
parameter READ_END  = 2'b11;

reg [1:0] read_state;

always @(posedge clk or posedge rst) begin
    
    if (rst) begin
        RDATA   <= 32'd0;
        RRESP   <= 2'b00;
        RVALID  <= 1'b0;
        ARREADY <= 1'b0;
        read_state <= IDLE;
    end else begin

    case (read_state) 
    IDLE: begin
        ARREADY    <= 1'b1;  //condition for ARREADY
        if (ARVALID & ARREADY) begin
            ARREADY    <= 1'b0;
            rd_addr    <= ARADDR;
            read_state <= READ_DATA;
        end
    end 

    READ_DATA: begin
        // read handshake
            RDATA      <= rd_data;
            RVALID     <= 1'b1;
            read_state <= READ_END;
    end

    READ_END: begin
        if (RVALID & RREADY) begin
            RVALID     <= 1'b0;
            ARREADY    <= 1'b1;
            read_state <= IDLE;
        end
    end

    default: begin
        RDATA   <= 32'd0;
        RRESP   <= 2'b00;
        RVALID  <= 1'b0;
        ARREADY <= 1'b0;
        read_state <= IDLE;
    end
    endcase

    end

end

    
endmodule