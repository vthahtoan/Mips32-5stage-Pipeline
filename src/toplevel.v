module toplevel(
    input clk,
    input pcreset,
    output [31:0] writeback,
    output [31:0] pc_out,
    output [4:0] rd,
    output enwrite
);

wire [31:0] inst;
wire jump;
wire [31:0] jump_address;
wire pcwrite;
wire if_id_write;
wire control_mux;

// --- IF STAGE ---
wire [31:0] pc;
wire [31:0] pc_4;
wire [31:0] pc_next;
wire ex_flush;
wire [31:0] branchpc;

assign pc_4 = pc + 4;
assign pc_next = (ex_flush) ? branchpc : (jump) ? jump_address : pc_4;

PC pc1 (
    .clk(clk),
    .pcreset(pcreset),
    .pcwrite(pcwrite),
    .pc_next(pc_next),
    .pc(pc)
);

IMEM imem1 (
    .readadr(pc),
    .inst(inst)
);

// --- IF_ID REGISTER ---
wire [31:0] if_id_inst;
wire [31:0] if_id_pc;

IF_ID_reg if_id_reg1 (
    .clk(clk),
    .pcreset(pcreset),
    .ex_flush(ex_flush),
    .jump(jump),
    .if_id_write(if_id_write),
    .inst_in(inst),
    .pc_4_in(pc_4),
    .if_id_inst(if_id_inst),
    .if_id_pc(if_id_pc)
);

// --- ID STAGE ---
wire regdst, branch, memread, memtoreg, memwrite, alusrc, id_regwrite, bne, is_sign_ext;
wire [2:0] aluop;

Controller controller1 (
    .inst(if_id_inst[31:26]),
    .regdst(regdst),
    .branch(branch),
    .memread(memread),
    .memtoreg(memtoreg),
    .aluop(aluop),
    .memwrite(memwrite),
    .alusrc(alusrc),
    .regwrite(regwrite),
    .bne(bne),
    .jump(jump),
    .is_sign_ext(is_sign_ext)
);

assign jump_address = {if_id_pc[31:28], if_id_inst[25:0], 2'b00};

wire [31:0] readdata1, readdata2;
wire [4:0] writereg;
assign writereg = (regdst) ? if_id_inst[15:11] : if_id_inst[20:16];
wire [4:0] shamt_wire = if_id_inst[10:6]; 
wire [31:0] mem_wb_data; 
wire [4:0] mem_wb_rd;
wire mem_wb_regwrite;

RegisterFile rf1 (
    .clk(clk),
	.reset(pcreset),
    .rs1(if_id_inst[25:21]),
    .rs2(if_id_inst[20:16]),
    .regwrite(mem_wb_regwrite),
    .writereg(mem_wb_rd),
    .readdata1(readdata1),
    .readdata2(readdata2),
    .writedata(mem_wb_data)
);

wire [31:0] signex;
Extender sign1(
    .a(if_id_inst[15:0]),
    .is_sign_ext(is_sign_ext),
    .b(signex)
);

// --- ID_EX REGISTER ---
wire id_ex_branch, id_ex_memread, id_ex_memtoreg, id_ex_memwrite;
wire id_ex_alusrc, id_ex_regwrite, id_ex_bne;
wire [2:0] id_ex_aluop;

wire [4:0] id_ex_rs1, id_ex_rs2, id_ex_rd;
wire [31:0] id_ex_signex, id_ex_data1, id_ex_data2, id_ex_pc;

wire [4:0] id_ex_shamt;

HazardDetection hazard_unit (
    .id_ex_memread(id_ex_memread),
    .id_ex_rd(id_ex_rd),
    .if_id_rs1(if_id_inst[25:21]),
    .if_id_rs2(if_id_inst[20:16]),
    .pcwrite(pcwrite),
    .if_id_write(if_id_write),
    .control_mux(control_mux)
);

ID_EX_reg id_ex_reg1 (
    .clk(clk),
    .pcreset(pcreset),
    .ex_flush(ex_flush),
    .control_mux(control_mux),
    
    .branch_in(branch),
    .memread_in(memread),
    .memtoreg_in(memtoreg),
    .aluop_in(aluop),
    .memwrite_in(memwrite),
    .alusrc_in(alusrc),
    .regwrite_in(regwrite),
    .bne_in(bne),
    
    .rs1_in(if_id_inst[25:21]),
    .rs2_in(if_id_inst[20:16]),
    .rd_in(writereg),
    .signex_in(signex),
    .data1_in(readdata1),
    .data2_in(readdata2),
    .pc_in(if_id_pc),
    .shamt_in(shamt_wire),
    
    .id_ex_branch(id_ex_branch),
    .id_ex_memread(id_ex_memread),
    .id_ex_memtoreg(id_ex_memtoreg),
    .id_ex_aluop(id_ex_aluop),
    .id_ex_memwrite(id_ex_memwrite),
    .id_ex_alusrc(id_ex_alusrc),
    .id_ex_regwrite(id_ex_regwrite),
    .id_ex_bne(id_ex_bne),
    
    .id_ex_rs1(id_ex_rs1),
    .id_ex_rs2(id_ex_rs2),
    .id_ex_rd(id_ex_rd),
    .id_ex_signex(id_ex_signex),
    .id_ex_data1(id_ex_data1),
    .id_ex_data2(id_ex_data2),
    .id_ex_pc(id_ex_pc),
    .id_ex_shamt(id_ex_shamt)
);

// --- EX STAGE ---
wire [1:0] sela, selb;
reg [31:0] a, b;

wire [31:0] balu, result;
wire is0;

wire [4:0] ex_mem_rd;
wire ex_mem_regwrite;
wire [31:0] ex_mem_result;

Forwarding forward1(
    .id_ex_rs1(id_ex_rs1),
    .id_ex_rs2(id_ex_rs2),
    .ex_mem_rd(ex_mem_rd),
    .mem_wb_rd(mem_wb_rd),
    .ex_mem_regwrite(ex_mem_regwrite),
    .mem_wb_regwrite(mem_wb_regwrite),
    .sela(sela),
    .selb(selb)
);

always @(*) begin
    case(sela)
        2'b00: a = id_ex_data1;
        2'b01: a = ex_mem_result;
        2'b10: a = mem_wb_data;
        default: a = id_ex_data1;
    endcase
    case(selb)
        2'b00: b = id_ex_data2;
        2'b01: b = ex_mem_result;
        2'b10: b = mem_wb_data;
        default: b = id_ex_data2;
    endcase
end

assign balu = (id_ex_alusrc) ? id_ex_signex : b;

wire [5:0] aluctrl;

ALUControl aluctrl1(
    .aluop(id_ex_aluop),
    .funct(id_ex_signex[5:0]),
    .aluctrl(aluctrl)
);

ALU id_ex_reg1alu1(
    .a(a),
    .b(balu),
    .shamt(id_ex_shamt),
    .aluctrl(aluctrl),
    .result(result),
    .isz(is0)
);

assign branchpc = {id_ex_signex[29:0], 2'b00} + id_ex_pc;
assign ex_flush = (id_ex_branch && is0) || (id_ex_bne && !is0);

// --- EX_MEM REGISTER ---
wire ex_mem_memwrite, ex_mem_memread;
wire ex_mem_memtoreg;
wire [31:0] ex_mem_writedata, ex_mem_pc;

EX_MEM_reg ex_mem_reg1 (
    .clk(clk),
    .pcreset(pcreset),
    
    .result_in(result),
    .writedata_in(b),
    .rd_in(id_ex_rd),
    .pc_in(id_ex_pc),
    
    .memwrite_in(id_ex_memwrite),
    .memread_in(id_ex_memread),
    .regwrite_in(id_ex_regwrite),
    .memtoreg_in(id_ex_memtoreg),
    
    .ex_mem_result(ex_mem_result),
    .ex_mem_writedata(ex_mem_writedata),
    .ex_mem_rd(ex_mem_rd),
    .ex_mem_pc(ex_mem_pc),
    
    .ex_mem_memwrite(ex_mem_memwrite),
    .ex_mem_memread(ex_mem_memread),
    .ex_mem_regwrite(ex_mem_regwrite),
    .ex_mem_memtoreg(ex_mem_memtoreg)
);

// --- MEM STAGE ---
wire [31:0] memdata;
DMEM mem1(
    .clk(clk),
    .address(ex_mem_result),
    .writedata(ex_mem_writedata),
    .memwrite(ex_mem_memwrite),
    .memread(ex_mem_memread),
    .readdata(memdata)
);

// --- MEM_WB REGISTER ---
wire [31:0] mem_wb_alu_result;
wire [31:0] mem_wb_mem_data;
wire mem_wb_memtoreg;
wire [31:0] mem_wb_pc;

MEM_WB_reg mem_wb_reg1 (
    .clk(clk),
    .pcreset(pcreset),
    
    .alu_result_in(ex_mem_result),
    .mem_data_in(memdata),
    .rd_in(ex_mem_rd),
    .pc_in(ex_mem_pc),
    .memtoreg_in(ex_mem_memtoreg),
    .regwrite_in(ex_mem_regwrite),
    
    .mem_wb_alu_result(mem_wb_alu_result),
    .mem_wb_mem_data(mem_wb_mem_data),
    .mem_wb_rd(mem_wb_rd),
    .mem_wb_pc(mem_wb_pc),
    .mem_wb_memtoreg(mem_wb_memtoreg),
    .mem_wb_regwrite(mem_wb_regwrite)
);

// --- WB STAGE ---
assign mem_wb_data = (mem_wb_memtoreg) ? mem_wb_mem_data : mem_wb_alu_result;

assign writeback = mem_wb_data;
assign pc_out = mem_wb_pc - 4;
assign rd = mem_wb_rd;
assign enwrite = mem_wb_regwrite;

endmodule