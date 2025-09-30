module WRITE_SRC #(
    parameter DATAWIDTH = 32,
    parameter MAX_LENGTH = 16, ///max length of data to be transfered in bytes
    parameter LEN = $clog2(MAX_LENGTH) + 1
) (
    // generic control signals 
    input clk, rst,

    // AW - write address channel 
    input   [DATAWIDTH-1:0] AWADDR,
    input                   AWVALID, 
    input   [2:0]           AWPROT,  //for future use 
    output  reg             AWREADY,

    // W - write data channel 
    input  [DATAWIDTH-1:0] WDATA,
    input  [3:0]           WSTRB,
    input                  WVALID,
    output reg             WREADY,

    // B - Write response 
    output reg [1:0]    BRESP,  //for future use
    output reg          BVALID,
    input               BREADY,

    // Output 
    output [31:0] ram_out //output updated value.
);


// word(32 bits) -> [(byte)(byte)(byte)(byte)] //  byte is 8 bits
reg [DATAWIDTH-1 : 0] RAM [DATAWIDTH-1 : 0]; 
// data to be transfered and recieved in bytes
reg  [LEN-1       : 0] addr;

reg wr_ena, addr_flag, data_flag;
reg [DATAWIDTH-1:0] wr_addr, wr_data;
reg [3:0] strb;

// input memory addr will always be multiple of 4 here 
always @(*) begin
    addr  = wr_addr[6:2];
end

assign ram_out = {
            strb[3] ? wr_data[31:24] : RAM[addr][31:24],
            strb[2] ? wr_data[23:16] : RAM[addr][23:16], 
            strb[1] ? wr_data[15:8]  : RAM[addr][15:8],
            strb[0] ? wr_data[7:0]   : RAM[addr][7:0]
        };

// synchronous write 
always @(posedge clk) begin
    if (rst) begin
        // optional reset logic
        BVALID  <= 0;
    end else if (wr_ena) begin
        // alligned output
        if (strb[0]) RAM[addr][7:0]   <= wr_data[7:0];
        if (strb[1]) RAM[addr][15:8]  <= wr_data[15:8];
        if (strb[2]) RAM[addr][23:16] <= wr_data[23:16];
        if (strb[3]) RAM[addr][31:24] <= wr_data[31:24];
        // responce channel
        BVALID <= 1;
    end else begin
        if (BVALID & BREADY) begin
            BVALID <= 0;
        end
    end
end

always @(negedge clk or posedge rst) begin

    if (rst) begin
        AWREADY <= 0;
        WREADY  <= 0;
        data_flag <= 0;
        addr_flag <= 0;
        wr_ena    <= 0;
    end else begin

        // always ready in prior to recieve data. 
        AWREADY   <= 1;
        WREADY    <= 1;
        
        if (data_flag & addr_flag) begin
            // reset flags
            data_flag <= 0; 
            addr_flag <= 0;
            wr_ena    <= 1;
            BVALID    <= 1;
        end
        else begin
            wr_ena <= 0;
        end

        // addr handshake
        if(AWVALID) begin
            wr_addr <= AWADDR;
            addr_flag <= 1; //set flag
        end
        
        //data handshake
        if (WVALID)  begin
            strb    <= WSTRB;
            wr_data <= WDATA;
            data_flag <= 1; //set flag
        end

    end 
    
end


endmodule