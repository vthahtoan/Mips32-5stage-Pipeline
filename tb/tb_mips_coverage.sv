`timescale 1ns/1ps
module tb_mips_coverage #(parameter integer FAMILY = 0);
    wire clk, active;
    wire signed [31:0] program_words;
    wire [31:0] wb_pc, mem_pc, ex_pc, id_pc;
    wire [31:0] wb_instruction, mem_instruction, ex_instruction, id_instruction;
    wire wb_write, mem_read, mem_write;
    wire [4:0] wb_rd, ex_rd;
    wire [31:0] memory_address;
    wire ex_regwrite, ex_load, ex_store, ex_branch, ex_bne;
    wire taken, id_jump, pcwrite;
    wire [1:0] sela, selb;
`define CONNECT_COVERAGE(TB) \
    assign clk = TB.clk; \
    assign active = TB.pcreset; \
    assign program_words = TB.program_words; \
    assign wb_pc = TB.uut.mem_wb_pc; \
    assign mem_pc = TB.uut.ex_mem_pc; \
    assign ex_pc = TB.uut.id_ex_pc; \
    assign id_pc = TB.uut.if_id_pc; \
    assign id_instruction = TB.uut.if_id_inst; \
    assign wb_write = TB.enwrite; \
    assign wb_rd = TB.rd; \
    assign ex_rd = TB.uut.id_ex_rd; \
    assign mem_read = TB.uut.ex_mem_memread; \
    assign mem_write = TB.uut.ex_mem_memwrite; \
    assign memory_address = TB.uut.ex_mem_result; \
    assign ex_regwrite = TB.uut.id_ex_regwrite; \
    assign ex_load = TB.uut.id_ex_memread; \
    assign ex_store = TB.uut.id_ex_memwrite; \
    assign ex_branch = TB.uut.id_ex_branch; \
    assign ex_bne = TB.uut.id_ex_bne; \
    assign taken = TB.uut.ex_flush; \
    assign id_jump = TB.uut.jump; \
    assign pcwrite = TB.uut.pcwrite; \
    assign sela = TB.uut.sela; \
    assign selb = TB.uut.selb; \
    assign wb_instruction = (TB.uut.mem_wb_pc >= 4 && TB.uut.mem_wb_pc <= $unsigned(TB.program_words)*4) ? TB.uut.imem1.mem[(TB.uut.mem_wb_pc - 32'd4) >> 2] : 32'd0; \
    assign mem_instruction = (TB.uut.ex_mem_pc >= 4 && TB.uut.ex_mem_pc <= $unsigned(TB.program_words)*4) ? TB.uut.imem1.mem[(TB.uut.ex_mem_pc - 32'd4) >> 2] : 32'd0; \
    assign ex_instruction = (TB.uut.id_ex_pc >= 4 && TB.uut.id_ex_pc <= $unsigned(TB.program_words)*4) ? TB.uut.imem1.mem[(TB.uut.id_ex_pc - 32'd4) >> 2] : 32'd0;
    generate
        if (FAMILY == 0) begin : directed
            tb_mips_scoreboard test();
            `CONNECT_COVERAGE(test)
        end
        else if (FAMILY == 1) begin : alu
            tb_mips_random_alu test();
            `CONNECT_COVERAGE(test)
        end
        else if (FAMILY == 2) begin : memory
            tb_mips_random_memory test();
            `CONNECT_COVERAGE(test)
        end
        else if (FAMILY == 3) begin : branch
            tb_mips_random_branch test();
            `CONNECT_COVERAGE(test)
        end
        else begin : invalid_family
            initial $fatal(1, "Coverage FAMILY must be 0..3");
        end
    endgenerate
    mips_coverage_monitor monitor (
        .clk(clk),
        .active(active),
        .program_words(program_words),
        .wb_instruction(wb_instruction),
        .mem_instruction(mem_instruction),
        .ex_instruction(ex_instruction),
        .wb_pc(wb_pc),
        .mem_pc(mem_pc),
        .ex_pc(ex_pc),
        .id_pc(id_pc),
        .id_instruction(id_instruction),
        .wb_write(wb_write),
        .wb_rd(wb_rd),
        .ex_rd(ex_rd),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .memory_address(memory_address),
        .ex_regwrite(ex_regwrite),
        .ex_load(ex_load),
        .ex_store(ex_store),
        .ex_branch(ex_branch),
        .ex_bne(ex_bne),
        .taken(taken),
        .id_jump(id_jump),
        .pcwrite(pcwrite),
        .sela(sela),
        .selb(selb)
    );
endmodule
`undef CONNECT_COVERAGE
