module Forwarding(
	input [4:0]id_ex_rs1,
	input [4:0]id_ex_rs2,
	input [4:0]ex_mem_rd,
	input [4:0]mem_wb_rd,
	input ex_mem_regwrite,
	input mem_wb_regwrite,
	output reg [1:0] sela,
	output reg [1:0] selb
);
//sel = 0 Lấy dữ liệu gốc từ thanh ghi ID/EX 
//sel = 1 Lấy kết quả ALU từ thanh ghi EX/MEM 
//sel = 2 Lấy dữ liệu từ thanh ghi MEM/WB 
always @(*) begin
    if (id_ex_rs1 == ex_mem_rd && ex_mem_regwrite && ex_mem_rd != 0)
        sela = 2'd1;
    else if (id_ex_rs1 == mem_wb_rd && mem_wb_regwrite && mem_wb_rd != 0)
        sela = 2'd2;
    else 
        sela = 2'd0;

    if (id_ex_rs2 == ex_mem_rd && ex_mem_regwrite && ex_mem_rd != 0)
        selb = 2'd1;
    else if (id_ex_rs2 == mem_wb_rd && mem_wb_regwrite && mem_wb_rd != 0)
        selb = 2'd2;
    else 
        selb = 2'd0;
end
endmodule