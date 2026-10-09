`timescale 1ns/1ps
module tb_mips_coverage_monitor_check;
    import mips_instruction_pkg::*;
    logic clk = 0, active = 1;
    integer program_words = 8;
    logic [31:0] wb_pc, mem_pc, ex_pc, id_pc;
    logic [31:0] wb_instruction, mem_instruction, ex_instruction, id_instruction;
    logic wb_write, mem_read, mem_write;
    logic [4:0] wb_rd, ex_rd;
    logic [31:0] memory_address;
    logic ex_regwrite, ex_load, ex_store, ex_branch, ex_bne;
    logic taken, id_jump, pcwrite;
    logic [1:0] sela, selb;
    integer test_completed = 0;
    mips_coverage_monitor monitor (.*);
    always #5 clk = ~clk;
    function automatic bit [31:0] encoded(input instruction_kind_t kind,
                                          input bit [4:0] rs, rt, rd,
                                          input bit [15:0] immediate,
                                          input bit [25:0] target = 0);
        mips_instruction instruction;
        instruction = new(kind, rs, rt, rd, immediate, 0, target);
        return instruction.encode();
    endfunction
    task automatic idle();
        wb_pc = 0; mem_pc = 0; ex_pc = 0; id_pc = 0;
        wb_instruction = 0; mem_instruction = 0; ex_instruction = 0; id_instruction = 0;
        wb_write = 0; mem_read = 0; mem_write = 0; wb_rd = 0; ex_rd = 0;
        memory_address = 0; ex_regwrite = 0; ex_load = 0; ex_store = 0;
        ex_branch = 0; ex_bne = 0; taken = 0; id_jump = 0; pcwrite = 1; sela = 0; selb = 0;
    endtask
    task automatic tick();
        @(posedge clk);
        #1;
    endtask
    initial begin
        idle();
        #1;
        ex_pc = 8;
        ex_instruction = encoded(MIPS_ADD, 1, 2, 3, 0);
        sela = 1; selb = 2;
        tick();
        if (monitor.forwarding_mask != 0 || monitor.sampled_events != 0)
            $fatal(1, "Coverage incorrectly sampled a pipeline bubble");
        idle();
        wb_pc = 4; wb_instruction = encoded(MIPS_LW, 0, 0, 0, 0); wb_write = 1;
        tick();
        if (monitor.load_destination_mask != 2 || monitor.sampled_events != 1)
            $fatal(1, "Coverage missed a real LW targeting r0");
        idle();
        mem_pc = 8; mem_instruction = encoded(MIPS_SW, 0, 1, 0, 1020);
        mem_write = 1; memory_address = 1020;
        tick();
        if (monitor.memory_address_mask != 32 || monitor.memory_offset_mask != 32)
            $fatal(1, "Coverage memory cross/index mismatch");
        idle();
        ex_pc = 12; ex_instruction = encoded(MIPS_BEQ, 1, 2, 0, 2); ex_branch = 1; taken = 1;
        id_pc = 16; id_instruction = encoded(MIPS_J, 0, 0, 0, 0, 6); id_jump = 1;
        tick();
        if (monitor.jump_mask != 2 || (monitor.instruction_mask & 65536) != 0 || monitor.sampled_events != 3)
            $fatal(1, "Coverage counted a cancelled jump as an executed instruction");
        idle();
        id_pc = 16; id_instruction = encoded(MIPS_J, 0, 0, 0, 0, 6); id_jump = 1;
        tick();
        if (monitor.jump_mask != 3 || monitor.sampled_events != 4)
            $fatal(1, "Coverage missed an accepted jump");
        idle();
        wb_pc = 36; wb_instruction = encoded(MIPS_ADD, 1, 2, 3, 0); wb_write = 1; wb_rd = 3;
        tick();
        if ((monitor.instruction_mask & 32) != 0 || monitor.sampled_events != 4)
            $fatal(1, "Coverage sampled an instruction beyond the loaded program");
        idle();
        wb_pc = 4; wb_instruction = encoded(MIPS_LW, 0, 1, 0, 0); wb_write = 1; wb_rd = 1;
        ex_pc = 12; ex_instruction = encoded(MIPS_ADD, 1, 2, 3, 0); ex_regwrite = 1; sela = 2;
        tick();
        if (monitor.load_distance_mask != 2) $fatal(1, "Coverage missed the one-instruction load gap");
        ex_pc = 8;
        tick();
        if (monitor.load_distance_mask != 3 || monitor.load_destination_mask != 3)
            $fatal(1, "Coverage missed immediate load use or load destination bins");
        idle();
        ex_pc = 8; ex_instruction = encoded(MIPS_LW, 0, 1, 0, 0); ex_load = 1; ex_rd = 1;
        id_pc = 12; id_instruction = encoded(MIPS_BEQ, 1, 2, 0, 2); pcwrite = 0;
        tick();
        id_instruction = encoded(MIPS_SW, 0, 1, 0, 0);
        tick();
        id_instruction = encoded(MIPS_ADD, 1, 2, 3, 0);
        tick();
        if (monitor.hazard_mask != 7 || monitor.monitor_errors != 0 || monitor.sampled_events != 6 ||
            monitor.instruction_mask != 81944 || monitor.branch_outcome_mask != 2)
            $fatal(1, "Coverage observer self-check failed");
        test_completed = 1;
        $display("COVERAGE MONITOR CHECK PASS: bubbles, r0, cancelled jumps, bounds, load gaps and hazards");
        $finish;
    end
endmodule
