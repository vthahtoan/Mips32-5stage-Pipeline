module toplevel_single_cycle(
    input clk,
    input reset
);

    // --- 1. Program Counter (PC) ---
    reg [31:0] pc;
    wire [31:0] pc_next, pc_plus4, branch_addr, jump_addr;
    wire [31:0] pc_after_branch;
    
    always @(posedge clk or negedge reset) begin
        if (!reset)
            pc <= 32'd0;
        else
            pc <= pc_next;
    end

    assign pc_plus4 = pc + 4;

    // --- 2. Instruction Memory (IMEM) ---
    wire [31:0] inst;
    IMEM imem1 (
        .readadr(pc),
        .inst(inst)
    );

    // --- 3. Main Controller ---
    wire regdst, branch, memread, memtoreg, memwrite, alusrc, regwrite;
    wire [2:0] aluop;
    wire jump; // Đã thêm tín hiệu jump như thảo luận trước đó

    Controller controller1 (
        .inst(inst[31:26]),
        .regdst(regdst),
        .branch(branch),
        .memread(memread),
        .memtoreg(memtoreg),
        .aluop(aluop),
        .memwrite(memwrite),
        .alusrc(alusrc),
        .regwrite(regwrite)
        // .jump(jump) // Mở comment nếu bạn đã thêm output jump vào Controller.v
    );
    assign jump = (inst[31:26] == 6'h02); // Logic dự phòng cho lệnh Jump

    // --- 4. Register File ---
    wire [4:0] write_reg;
    wire [31:0] write_data, readdata1, readdata2;

    // MUX chọn thanh ghi đích (rt hoặc rd)
    assign write_reg = (regdst) ? inst[15:11] : inst[20:16];

    RegisterFile rf1 (
        .clk(clk),
        .rs1(inst[25:21]),
        .rs2(inst[20:16]),
        .writereg(write_reg),
        .writedata(write_data),
        .regwrite(regwrite),
        .readdata1(readdata1),
        .readdata2(readdata2)
    );

    // --- 5. Sign Extend ---
    wire [31:0] extended_imm;
    SignExtend se1 (
        .a(inst[15:0]),
        .b(extended_imm)
    );

    // --- 6. ALU & ALU Control ---
    wire [5:0] aluctrl;
    wire [31:0] alu_in2, alu_result;
    wire is_zero;

    AluControl alu_ctrl1 (
        .funct(inst[5:0]),
        .AluOp(aluop),
        .aluctrl(aluctrl)
    );

    // MUX chọn nguồn thứ 2 cho ALU (ReadData2 hoặc Immediate)
    assign alu_in2 = (alusrc) ? extended_imm : readdata2;

    ALU alu1 (
        .a(readdata1),
        .b(alu_in2),
        .aluctrl(aluctrl),
        .result(alu_result),
        .isz(is_zero)
    );

    // --- 7. Data Memory (DMEM) ---
    wire [31:0] mem_readdata;
    DMEM dmem1 (
        .clk(clk),
        .address(alu_result),
        .writedata(readdata2),
        .memwrite(memwrite),
        .memread(memread),
        .readdata(mem_readdata)
    );

    // MUX chọn dữ liệu ghi lại Register File (ALU result hoặc Memory)
    assign write_data = (memtoreg) ? mem_readdata : alu_result;

    // --- 8. Next PC Logic (Branch & Jump) ---
    
    // Tính địa chỉ Branch: (PC+4) + (Imm << 2)
    assign branch_addr = pc_plus4 + {extended_imm[29:0], 2'b00};
    
    // MUX chọn giữa PC+4 và Branch Address
    assign pc_after_branch = (branch && is_zero) ? branch_addr : pc_plus4;

    // Tính địa chỉ Jump: {PC+4[31:28], address[25:0], 00}
    assign jump_addr = {pc_plus4[31:28], inst[25:0], 2'b00};

    // MUX cuối cùng chọn PC_next
    assign pc_next = (jump) ? jump_addr : pc_after_branch;

endmodule