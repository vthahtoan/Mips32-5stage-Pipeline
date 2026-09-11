module MEM_WB_reg (
    input clk,
    input pcreset,

    input [31:0] alu_result_in,
    input [31:0] mem_data_in,
    input [4:0]  rd_in,
    input [31:0] pc_in,

    input memtoreg_in,
    input regwrite_in,

    output reg [31:0] mem_wb_alu_result,
    output reg [31:0] mem_wb_mem_data,
    output reg [4:0]  mem_wb_rd,
    output reg [31:0] mem_wb_pc,
    
    output reg mem_wb_memtoreg,
    output reg mem_wb_regwrite
);

always @(posedge clk or negedge pcreset) begin
    if (!pcreset) begin
        mem_wb_alu_result <= 32'd0;
        mem_wb_mem_data   <= 32'd0;
        mem_wb_rd         <= 5'd0;
        mem_wb_pc         <= 32'd0;
        mem_wb_memtoreg   <= 1'b0;
        mem_wb_regwrite   <= 1'b0;
    end else begin
        mem_wb_alu_result <= alu_result_in;
        mem_wb_mem_data   <= mem_data_in;
        mem_wb_rd         <= rd_in;
        mem_wb_pc         <= pc_in;
        mem_wb_memtoreg   <= memtoreg_in;
        mem_wb_regwrite   <= regwrite_in;
    end
end

endmodule