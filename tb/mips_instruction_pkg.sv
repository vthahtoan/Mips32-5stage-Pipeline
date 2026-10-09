package mips_instruction_pkg;
    typedef enum {MIPS_ADDI, MIPS_ANDI, MIPS_ORI, MIPS_SW, MIPS_LW,
                  MIPS_ADD, MIPS_SUB, MIPS_AND, MIPS_OR, MIPS_NOR,
                  MIPS_XOR, MIPS_SLT, MIPS_SLL, MIPS_SRL,
                  MIPS_BEQ, MIPS_BNE, MIPS_J} instruction_kind_t;
    class mips_instruction;
        instruction_kind_t kind;
        bit [4:0] rs, rt, rd;
        bit [15:0] imm;
        bit [4:0] shamt;
        bit [25:0] target;
        function new(instruction_kind_t kind,
                     bit [4:0] rs, bit [4:0] rt,
                     bit [4:0] rd, bit [15:0] imm,
                     bit [4:0] shamt = 0, bit [25:0] target = 0);
            this.kind = kind;
            this.rs = rs;
            this.rt = rt;
            this.rd = rd;
            this.imm = imm;
            this.shamt = shamt;
            this.target = target;
        endfunction
        function bit [31:0] encode();
            case (kind)
                MIPS_ADDI: return {6'h08, rs, rt, imm};
                MIPS_ANDI: return {6'h0c, rs, rt, imm};
                MIPS_ORI:  return {6'h0d, rs, rt, imm};
                MIPS_SW:   return {6'h2b, rs, rt, imm};
                MIPS_LW:   return {6'h23, rs, rt, imm};
                MIPS_BEQ:  return {6'h04, rs, rt, imm};
                MIPS_BNE:  return {6'h05, rs, rt, imm};
                MIPS_ADD:  return {6'h00, rs, rt, rd, 5'd0, 6'h20};
                MIPS_SUB:  return {6'h00, rs, rt, rd, 5'd0, 6'h22};
                MIPS_AND:  return {6'h00, rs, rt, rd, 5'd0, 6'h24};
                MIPS_OR:   return {6'h00, rs, rt, rd, 5'd0, 6'h25};
                MIPS_NOR:  return {6'h00, rs, rt, rd, 5'd0, 6'h27};
                MIPS_XOR:  return {6'h00, rs, rt, rd, 5'd0, 6'h26};
                MIPS_SLT:  return {6'h00, rs, rt, rd, 5'd0, 6'h2a};
                MIPS_SLL:  return {6'h00, 5'd0, rt, rd, shamt, 6'h00};
                MIPS_SRL:  return {6'h00, 5'd0, rt, rd, shamt, 6'h02};
                MIPS_J:    return {6'h02, target};
                default: begin
                    $fatal(1, "Unsupported instruction kind");
                    return 32'd0;
                end
            endcase
        endfunction
    endclass
endpackage
