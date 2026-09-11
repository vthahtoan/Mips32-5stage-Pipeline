module ID_EX_reg (
    input clk,
    input pcreset,
    input ex_flush,
    input control_mux,
    
    input branch_in,
    input memread_in,
    input memtoreg_in,
    input [2:0] aluop_in,
    input memwrite_in,
    input alusrc_in,
    input regwrite_in,
    input bne_in,
    
    input [4:0] rs1_in,
    input [4:0] rs2_in,
    input [4:0] rd_in,
    input [31:0] signex_in,
    input [31:0] data1_in,
    input [31:0] data2_in,
    input [31:0] pc_in,
    input [4:0] shamt_in,
    
    output reg id_ex_branch,
    output reg id_ex_memread,
    output reg id_ex_memtoreg,
    output reg [2:0] id_ex_aluop,
    output reg id_ex_memwrite,
    output reg id_ex_alusrc,
    output reg id_ex_regwrite,
    output reg id_ex_bne,
    
    output reg [4:0] id_ex_rs1,
    output reg [4:0] id_ex_rs2,
    output reg [4:0] id_ex_rd,
    output reg [31:0] id_ex_signex,
    output reg [31:0] id_ex_data1,
    output reg [31:0] id_ex_data2,
    output reg [31:0] id_ex_pc,
    output reg [4:0] id_ex_shamt
);

always @(posedge clk or negedge pcreset) begin
    if (!pcreset) begin
        id_ex_branch   <= 0;
        id_ex_memread  <= 0;
        id_ex_memtoreg <= 0; 
        id_ex_aluop    <= 0;
        id_ex_memwrite <= 0;
        id_ex_alusrc   <= 0;
        id_ex_regwrite <= 0;
        id_ex_bne      <= 0;
        id_ex_rs1      <= 0;      
        id_ex_rs2      <= 0;
        id_ex_rd       <= 0;       
        id_ex_signex   <= 0;
        id_ex_data1    <= 0;
        id_ex_data2    <= 0;
        id_ex_pc       <= 0;
        id_ex_shamt    <= 0;
    end else if (ex_flush) begin
        id_ex_branch   <= 0;
        id_ex_memread  <= 0;
        id_ex_memtoreg <= 0; 
        id_ex_aluop    <= 0;
        id_ex_memwrite <= 0;
        id_ex_alusrc   <= 0;
        id_ex_regwrite <= 0;
        id_ex_bne      <= 0;
        id_ex_rs1      <= 0;      
        id_ex_rs2      <= 0;
        id_ex_rd       <= 0;       
        id_ex_signex   <= 0;
        id_ex_data1    <= 0;
        id_ex_data2    <= 0;
        id_ex_pc       <= 0;
        id_ex_shamt    <= 0;
    end else begin      
        id_ex_branch   <= branch_in   & control_mux;
        id_ex_memread  <= memread_in  & control_mux;
        id_ex_memtoreg <= memtoreg_in & control_mux;
        id_ex_aluop    <= aluop_in    & {3{control_mux}}; 
        id_ex_memwrite <= memwrite_in & control_mux;
        id_ex_alusrc   <= alusrc_in   & control_mux;
        id_ex_regwrite <= regwrite_in & control_mux;
        id_ex_bne      <= bne_in      & control_mux;
        
        id_ex_rs1      <= rs1_in;
        id_ex_rs2      <= rs2_in;
        id_ex_rd       <= rd_in;
        id_ex_signex   <= signex_in;
        id_ex_data1    <= data1_in;
        id_ex_data2    <= data2_in;
        id_ex_pc       <= pc_in;
        id_ex_shamt    <= shamt_in;
    end
end

endmodule