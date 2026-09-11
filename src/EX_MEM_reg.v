module EX_MEM_reg (
    input clk,
    input pcreset,

    input [31:0] result_in,
    input [31:0] writedata_in,
    input [4:0] rd_in,
    input [31:0] pc_in,
    
    input memwrite_in,
    input memread_in,
    input regwrite_in,
    input memtoreg_in,

    output reg [31:0] ex_mem_result,
    output reg [31:0] ex_mem_writedata,
    output reg [4:0] ex_mem_rd,
    output reg [31:0] ex_mem_pc,
    
    output reg ex_mem_memwrite,
    output reg ex_mem_memread,
    output reg ex_mem_regwrite,
    output reg ex_mem_memtoreg
);

always @(posedge clk or negedge pcreset) begin
    if (!pcreset) begin
        ex_mem_result    <= 32'd0;
        ex_mem_writedata <= 32'd0;
        ex_mem_rd        <= 5'd0;
        ex_mem_pc        <= 32'd0;
        
        ex_mem_memwrite  <= 1'b0;
        ex_mem_memread   <= 1'b0;
        ex_mem_regwrite  <= 1'b0;
        ex_mem_memtoreg  <= 1'b0;
    end else begin
        ex_mem_result    <= result_in;
        ex_mem_writedata <= writedata_in;
        ex_mem_rd        <= rd_in;
        ex_mem_pc        <= pc_in;
        
        ex_mem_memwrite  <= memwrite_in;
        ex_mem_memread   <= memread_in;
        ex_mem_regwrite  <= regwrite_in;
        ex_mem_memtoreg  <= memtoreg_in;
    end
end

endmodule