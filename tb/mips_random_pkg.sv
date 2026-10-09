package mips_random_pkg;
    import mips_instruction_pkg::*;
    class mips_random_instruction;
        rand instruction_kind_t kind;
        rand bit [4:0] rs, rt, rd;
        rand bit [15:0] imm;
        rand bit [4:0] shamt;
        constraint alu_kinds {
            solve kind before rs, rt, rd, imm, shamt;
            kind inside {MIPS_ADDI, MIPS_ANDI, MIPS_ORI,
                         MIPS_ADD, MIPS_SUB, MIPS_AND, MIPS_OR,
                         MIPS_NOR, MIPS_XOR, MIPS_SLT, MIPS_SLL, MIPS_SRL};
        }
        constraint instruction_fields {
            if (kind inside {MIPS_ADDI, MIPS_ANDI, MIPS_ORI}) {
                rd == 0;
                shamt == 0;
                imm dist {16'h0000 := 2, 16'h0001 := 2,
                          16'h7fff := 2, 16'h8000 := 2, 16'hffff := 2,
                          [16'h0002:16'h7ffe] :/ 3,
                          [16'h8001:16'hfffe] :/ 3};
            } else if (kind inside {MIPS_SLL, MIPS_SRL}) {
                rs == 0;
                imm == 0;
                shamt dist {5'd0 := 3, 5'd31 := 3, [5'd1:5'd30] :/ 6};
            } else {
                imm == 0;
                shamt == 0;
            }
        }
        function bit [31:0] encode();
            mips_instruction instruction;
            instruction = new(kind, rs, rt, rd, imm, shamt, 26'd0);
            return instruction.encode();
        endfunction
    endclass
endpackage
