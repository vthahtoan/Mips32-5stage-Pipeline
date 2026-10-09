package mips_reference_pkg;
    class mips_reference_model;
        logic [31:0] regs [0:31];
        logic [31:0] imem [0:255];
        logic [31:0] dmem [0:255];
        bit [31:0] pc;
        integer steps;
        integer write_count;
        integer branches_taken;
        integer branches_not_taken;
        integer jumps;
        function new();
            reset();
        endfunction
        function void reset();
            for (int i = 0; i < 32; i++) regs[i] = 0;
            for (int i = 0; i < 256; i++) begin
                imem[i] = 0;
                dmem[i] = 0;
            end
            pc = 0;
            steps = 0;
            write_count = 0;
            branches_taken = 0;
            branches_not_taken = 0;
            jumps = 0;
        endfunction
        function void write_register(bit [4:0] dest, logic [31:0] value);
            if (dest != 0) begin
                regs[dest] = value;
                write_count++;
            end
        endfunction
        function void check_address(logic [31:0] address);
            if ((^address) === 1'bx || address[1:0] !== 2'b00 ||
                address >= 32'd1024)
                $fatal(1, "REF invalid data address: pc=%08h address=%08h", pc, address);
        endfunction
        function void step();
            logic [31:0] instruction, a, b, sign_imm, zero_imm;
            logic [31:0] address;
            bit [31:0] next_pc;
            bit [5:0] opcode, funct;
            bit [4:0] rs, rt, rd, shamt;
            if (pc[1:0] != 0 || pc >= 32'd1024)
                $fatal(1, "REF invalid instruction address: %08h", pc);
            instruction = imem[pc >> 2];
            if ((^instruction) === 1'bx)
                $fatal(1, "REF instruction contains X/Z at pc=%08h", pc);
            opcode = instruction[31:26];
            rs = instruction[25:21];
            rt = instruction[20:16];
            rd = instruction[15:11];
            shamt = instruction[10:6];
            funct = instruction[5:0];
            a = regs[rs];
            b = regs[rt];
            sign_imm = {{16{instruction[15]}}, instruction[15:0]};
            zero_imm = {16'd0, instruction[15:0]};
            next_pc = pc + 4;
            case (opcode)
                6'h00: begin
                    case (funct)
                        6'h20: write_register(rd, a + b);
                        6'h22: write_register(rd, a - b);
                        6'h24: write_register(rd, a & b);
                        6'h25: write_register(rd, a | b);
                        6'h27: write_register(rd, ~(a | b));
                        6'h26: write_register(rd, a ^ b);
                        6'h2a: write_register(rd, ($signed(a) < $signed(b)) ? 32'd1 : 32'd0);
                        6'h00: write_register(rd, b << shamt);
                        6'h02: write_register(rd, b >> shamt);
                        default: $fatal(1, "REF unsupported funct=%02h pc=%08h", funct, pc);
                    endcase
                end
                6'h08: write_register(rt, a + sign_imm);
                6'h0c: write_register(rt, a & zero_imm);
                6'h0d: write_register(rt, a | zero_imm);
                6'h23: begin
                    address = a + sign_imm;
                    check_address(address);
                    write_register(rt, dmem[address >> 2]);
                end
                6'h2b: begin
                    address = a + sign_imm;
                    check_address(address);
                    dmem[address >> 2] = b;
                end
                6'h04: begin
                    if (a == b) begin
                        next_pc = next_pc + (sign_imm << 2);
                        branches_taken++;
                    end else branches_not_taken++;
                end
                6'h05: begin
                    if (a != b) begin
                        next_pc = next_pc + (sign_imm << 2);
                        branches_taken++;
                    end else branches_not_taken++;
                end
                6'h02: begin
                    next_pc = {next_pc[31:28], instruction[25:0], 2'b00};
                    jumps++;
                end
                default: $fatal(1, "REF unsupported opcode=%02h pc=%08h", opcode, pc);
            endcase
            regs[0] = 0;
            pc = next_pc;
            steps++;
        endfunction
        function void run(input integer program_words,
                          input integer max_steps = 256);
            if (program_words < 1 || program_words > 256 || max_steps < 1)
                $fatal(1, "REF invalid program length or instruction limit");
            while (pc < program_words * 4) begin
                if (steps >= max_steps)
                    $fatal(1, "REF instruction limit reached at pc=%08h", pc);
                step();
            end
        endfunction
    endclass
endpackage
