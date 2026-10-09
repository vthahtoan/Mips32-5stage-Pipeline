`timescale 1ns/1ps
module tb_mips_random_branch;
    import mips_instruction_pkg::*;
    import mips_reference_pkg::*;
    import mips_scoreboard_pkg::*;
    import mips_random_pkg::*;
    import mips_random_branch_pkg::*;
    mips_random_instruction initializer;
    mips_random_branch_scenario generator;
    mips_reference_model ref_model;
    mips_scoreboard scoreboard;
    logic clk = 0, pcreset = 0;
    logic [31:0] writeback, pc_out;
    logic [4:0] rd;
    logic enwrite;
    integer seed = 1, random_blocks = 12;
    integer program_words = 0, randomizations = 0, model_steps = 0;
    integer expected_steps = 31, expected_stalls = 0;
    integer expected_taken = 0, expected_not_taken = 0, expected_jumps = 0;
    integer expected_loads = 0, expected_stores = 0;
    integer writes_seen = 0, stalls_seen = 0, loads_seen = 0, stores_seen = 0;
    integer branches_taken = 0, branches_not_taken = 0, jumps_seen = 0;
    integer scenario_counts [0:7] = '{default:0};
    bit [31:0] loaded_scenarios = 0;
    integer run_cycles = 0;
    integer signal_errors = 0, scoreboard_checks = 0, scoreboard_errors = 0;
    string scoreboard_first_failure = "";
    integer test_completed = 0;
    toplevel uut (
        .clk(clk), .pcreset(pcreset), .writeback(writeback),
        .pc_out(pc_out), .rd(rd), .enwrite(enwrite)
    );
    always #5 clk = ~clk;
    always @(posedge clk) begin
        if (pcreset) begin
            if ((^{uut.pcwrite, enwrite, uut.id_ex_branch, uut.id_ex_bne,
                   uut.ex_flush, uut.jump, uut.ex_mem_memread,
                   uut.ex_mem_memwrite}) === 1'bx) begin
                signal_errors++;
                $display("BRANCH SIGNAL FAIL: seed=%0d time=%0t unknown control", seed, $time);
            end
            if (enwrite === 1'b1 &&
                ((^rd) === 1'bx || (rd != 0 && (^writeback) === 1'bx))) begin
                signal_errors++;
                $display("BRANCH SIGNAL FAIL: seed=%0d time=%0t unknown writeback", seed, $time);
            end
            if (uut.pcwrite === 1'b1 && ((^uut.pc) === 1'bx ||
                uut.pc[1:0] !== 2'b00 || uut.pc >= 32'd1024)) begin
                signal_errors++;
                $display("BRANCH SIGNAL FAIL: seed=%0d time=%0t invalid PC=%08h", seed, $time, uut.pc);
            end
            if (uut.ex_mem_memread === 1'b1 || uut.ex_mem_memwrite === 1'b1) begin
                if ((^uut.ex_mem_result) === 1'bx ||
                    uut.ex_mem_result[1:0] !== 2'b00 || uut.ex_mem_result >= 32'd1024) begin
                    signal_errors++;
                    $display("BRANCH SIGNAL FAIL: seed=%0d time=%0t invalid address=%08h",
                             seed, $time, uut.ex_mem_result);
                end
                if (uut.ex_mem_memwrite === 1'b1 && (^uut.ex_mem_writedata) === 1'bx) begin
                    signal_errors++;
                    $display("BRANCH SIGNAL FAIL: seed=%0d time=%0t unknown store data", seed, $time);
                end
                if (uut.ex_mem_memread === 1'b1 && (^uut.memdata) === 1'bx) begin
                    signal_errors++;
                    $display("BRANCH SIGNAL FAIL: seed=%0d time=%0t unknown load data", seed, $time);
                end
            end
            if (uut.pcwrite === 1'b0) stalls_seen++;
            if (enwrite === 1'b1 && rd != 0) writes_seen++;
            if (uut.ex_mem_memread === 1'b1) loads_seen++;
            if (uut.ex_mem_memwrite === 1'b1) stores_seen++;
            if (uut.id_ex_branch === 1'b1 || uut.id_ex_bne === 1'b1) begin
                if (uut.ex_flush === 1'b1) branches_taken++;
                else if (uut.ex_flush === 1'b0) branches_not_taken++;
            end
            if (uut.jump === 1'b1 && uut.pcwrite === 1'b1 &&
                uut.ex_flush === 1'b0) jumps_seen++;
        end
    end
    task automatic append_instruction(input instruction_kind_t kind,
                                      input bit [4:0] rs, rt, destination,
                                      input bit [15:0] immediate,
                                      input bit [25:0] target = 0);
        mips_instruction instruction;
        bit [31:0] machine_code;
        if (program_words >= 256) $fatal(1, "Branch program exceeds IMEM");
        instruction = new(kind, rs, rt, destination, immediate, 0, target);
        machine_code = instruction.encode();
        uut.imem1.mem[program_words] = machine_code;
        ref_model.imem[program_words] = machine_code;
        $display("BRANCH LOAD: seed=%0d index=%0d code=%08h kind=%s rs=%0d rt=%0d rd=%0d imm=%04h target=%0d",
                 seed, program_words, machine_code, kind.name(), rs, rt, destination, immediate, target);
        program_words++;
    endtask
    task automatic append_jump(input integer target_index);
        if (target_index < 0 || target_index >= 256)
            $fatal(1, "Branch test invalid jump target: %0d", target_index);
        append_instruction(MIPS_J, 0, 0, 0, 0, target_index[25:0]);
    endtask
    task automatic append_scenario(input integer block_index);
        integer start, poison_address, output_address, load_address;
        bit [15:0] poison_offset, output_offset, load_offset;
        bit [4:0] left_reg, right_reg, result_reg, counter_reg;
        bit [15:0] value, other_value, marker;
        bit [15:0] loop_iterations;
        bit taken, equal_operands;
        instruction_kind_t branch_kind;
        start = program_words;
        poison_address = block_index * 4;
        output_address = (block_index + 32) * 4;
        load_address = (block_index + 64) * 4;
        poison_offset = poison_address[15:0];
        output_offset = output_address[15:0];
        load_offset = load_address[15:0];
        left_reg = generator.left_reg;
        right_reg = generator.right_reg;
        result_reg = generator.result_reg;
        counter_reg = generator.counter_reg;
        value = generator.value;
        marker = generator.marker;
        loop_iterations = {13'd0, generator.iterations};
        scenario_counts[generator.scenario]++;
        loaded_scenarios[generator.scenario] = 1;
        $display("BRANCH BLOCK: seed=%0d start=%0d scenario=%s left=r%0d right=r%0d result=r%0d counter=r%0d value=%04h marker=%04h iterations=%0d",
                 seed, start, generator.scenario.name(), left_reg, right_reg,
                 result_reg, counter_reg, value, marker, loop_iterations);
        case (generator.scenario)
            CF_BEQ_TAKEN, CF_BEQ_NOT_TAKEN, CF_BNE_TAKEN, CF_BNE_NOT_TAKEN: begin
                branch_kind = (generator.scenario inside {CF_BEQ_TAKEN, CF_BEQ_NOT_TAKEN}) ? MIPS_BEQ : MIPS_BNE;
                equal_operands = generator.scenario inside {CF_BEQ_TAKEN, CF_BNE_NOT_TAKEN};
                taken = generator.scenario inside {CF_BEQ_TAKEN, CF_BNE_TAKEN};
                other_value = equal_operands ? value : (value ^ 16'd1);
                append_instruction(MIPS_ADDI, 0, left_reg, 0, value);
                append_instruction(MIPS_ADDI, 0, right_reg, 0, other_value);
                append_instruction(branch_kind, left_reg, right_reg, 0, 2);
                append_instruction(MIPS_SW, 0, left_reg, 0, poison_offset);
                if (taken)
                    append_instruction(MIPS_ADDI, 0, 31, 0, 1);
                else
                    append_instruction(MIPS_ADDI, 0, result_reg, 0, 1);
                append_instruction(MIPS_ADDI, 0, result_reg, 0, marker);
                append_instruction(MIPS_SW, 0, result_reg, 0, output_offset);
                expected_steps += taken ? 10 : 12;
                if (taken) expected_taken++;
                else expected_not_taken++;
                expected_stores += taken ? 1 : 2;
            end
            CF_JUMP_FORWARD: begin
                append_instruction(MIPS_ADDI, 0, left_reg, 0, value);
                append_jump(start + 5);
                append_instruction(MIPS_SW, 0, left_reg, 0, poison_offset);
                append_instruction(MIPS_ADDI, 0, 31, 0, 1);
                append_instruction(MIPS_ADDI, 0, result_reg, 0, 1);
                append_instruction(MIPS_ADDI, 0, result_reg, 0, marker);
                append_instruction(MIPS_SW, 0, result_reg, 0, output_offset);
                expected_steps += 9;
                expected_jumps++;
                expected_stores++;
            end
            CF_BOUNDED_LOOP: begin
                append_instruction(MIPS_ADDI, 0, counter_reg, 0, loop_iterations);
                append_instruction(MIPS_ADDI, 0, result_reg, 0, marker);
                append_instruction(MIPS_ADDI, result_reg, result_reg, 0, 1);
                append_instruction(MIPS_ADDI, counter_reg, counter_reg, 0, 16'hffff);
                append_instruction(MIPS_BNE, counter_reg, 0, 0, 16'hfffd);
                append_instruction(MIPS_SW, 0, result_reg, 0, output_offset);
                expected_steps += 12 + 3*(int'(loop_iterations) - 1);
                expected_taken += int'(loop_iterations) - 1;
                expected_not_taken++;
                expected_stores++;
            end
            CF_LOAD_BRANCH: begin
                append_instruction(MIPS_ADDI, 0, left_reg, 0, value);
                append_instruction(MIPS_SW, 0, left_reg, 0, load_offset);
                append_instruction(MIPS_LW, 0, right_reg, 0, load_offset);
                append_instruction(MIPS_BEQ, right_reg, left_reg, 0, 2);
                append_instruction(MIPS_SW, 0, left_reg, 0, poison_offset);
                append_instruction(MIPS_ADDI, 0, 31, 0, 1);
                append_instruction(MIPS_ADDI, 0, result_reg, 0, marker);
                append_instruction(MIPS_SW, 0, result_reg, 0, output_offset);
                expected_steps += 10;
                expected_taken++;
                expected_stalls++;
                expected_loads++;
                expected_stores += 2;
            end
            CF_BRANCH_OVER_JUMP: begin
                append_instruction(MIPS_ADDI, 0, left_reg, 0, value);
                append_instruction(MIPS_ADDI, 0, right_reg, 0, value);
                append_instruction(MIPS_BEQ, left_reg, right_reg, 0, 3);
                append_jump(start + 9);
                append_instruction(MIPS_SW, 0, left_reg, 0, poison_offset);
                append_instruction(MIPS_ADDI, 0, 31, 0, 1);
                append_instruction(MIPS_ADDI, 0, result_reg, 0, marker);
                append_jump(start + 11);
                append_instruction(MIPS_SW, 0, left_reg, 0, poison_offset);
                append_instruction(MIPS_ADDI, 0, 31, 0, 1);
                append_instruction(MIPS_ADDI, 0, result_reg, 0, 1);
                append_instruction(MIPS_SW, 0, result_reg, 0, output_offset);
                expected_steps += 6;
                expected_taken++;
                expected_jumps++;
                expected_stores++;
            end
            default: $fatal(1, "Invalid branch scenario");
        endcase
        while (program_words < start + 12)
            append_instruction(MIPS_SLL, 0, 0, 0, 0);
        if (program_words != start + 12) $fatal(1, "Branch scenario length mismatch");
    endtask
    task automatic sample_final_state();
        for (int r = 0; r < 32; r++) scoreboard.check_register(r, uut.rf1.register[r]);
        for (int m = 0; m < 256; m++) scoreboard.check_memory(m, uut.mem1.dmem[m]);
        scoreboard.check_counts(writes_seen, stalls_seen, branches_taken,
                                branches_not_taken, jumps_seen);
        scoreboard.check_word($unsigned(loads_seen), $unsigned(expected_loads), "CPU memory read count");
        scoreboard.check_word($unsigned(stores_seen), $unsigned(expected_stores), "CPU memory store count");
        scoreboard_checks = scoreboard.checks;
        scoreboard_errors = scoreboard.errors;
        scoreboard_first_failure = scoreboard.first_failure;
    endtask
    initial begin
        if ($value$plusargs("SEED=%d", seed)) begin end
        if ($value$plusargs("RANDOM_BLOCKS=%d", random_blocks)) begin end
        if (seed < 1) $fatal(1, "SEED must be a positive signed 32-bit integer");
        if (random_blocks < 8 || random_blocks > 16)
            $fatal(1, "RANDOM_BLOCKS must be between 8 and 16");
        ref_model = new();
        initializer = new();
        generator = new();
        initializer.srandom(seed);
        generator.srandom(seed);
        #1;
        for (int m = 0; m < 256; m++) begin
            uut.imem1.mem[m] = 0;
            uut.mem1.dmem[m] = 0;
        end
        for (int r = 1; r <= 30; r++) begin
            if (!initializer.randomize() with {kind == MIPS_ADDI; rs == 0; rt == r[4:0];})
                $fatal(1, "Branch initializer failed: seed=%0d register=%0d", seed, r);
            randomizations++;
            append_instruction(initializer.kind, initializer.rs, initializer.rt, 0, initializer.imm);
        end
        if (!initializer.randomize() with {kind == MIPS_ADDI; rs == 0; rt == 31; imm == 0;})
            $fatal(1, "Branch poison-register initializer failed: seed=%0d", seed);
        randomizations++;
        append_instruction(initializer.kind, initializer.rs, initializer.rt, 0, initializer.imm);
        for (int block_index = 0; block_index < random_blocks; block_index++) begin
            if (block_index < 8) begin
                if (!generator.randomize() with {int'(scenario) == block_index;})
                    $fatal(1, "Branch scenario initializer failed: seed=%0d block=%0d", seed, block_index);
            end else if (!generator.randomize())
                $fatal(1, "Branch randomize failed: seed=%0d block=%0d", seed, block_index);
            randomizations++;
            append_scenario(block_index);
        end
        ref_model.run(program_words, 1024);
        model_steps = ref_model.steps;
        if (model_steps != expected_steps || ref_model.branches_taken != expected_taken ||
            ref_model.branches_not_taken != expected_not_taken || ref_model.jumps != expected_jumps ||
            ref_model.regs[31] !== 32'd0)
            $fatal(1, "Branch program/model mismatch: seed=%0d steps=%0d/%0d taken=%0d/%0d not_taken=%0d/%0d jumps=%0d/%0d",
                   seed, model_steps, expected_steps, ref_model.branches_taken, expected_taken,
                   ref_model.branches_not_taken, expected_not_taken, ref_model.jumps, expected_jumps);
        scoreboard = new(ref_model, expected_stalls);
        run_cycles = model_steps + 2*expected_taken + expected_jumps + expected_stalls + 8;
        repeat (3) @(negedge clk);
        pcreset = 1;
        repeat (run_cycles) @(negedge clk);
        sample_final_state();
        if (signal_errors != 0 || scoreboard_errors != 0 || scoreboard_checks != 295 ||
            model_steps != expected_steps || program_words != 31 + 12*random_blocks ||
            randomizations != 31 + random_blocks || loaded_scenarios != 32'd255)
            $fatal(1, "RANDOM BRANCH FAIL: seed=%0d signals=%0d scoreboard=%0d first=%s",
                   seed, signal_errors, scoreboard_errors, scoreboard_first_failure);
        test_completed = 1;
        $display("RANDOM BRANCH TEST PASS: seed=%0d blocks=%0d words=%0d randomizations=%0d model_steps=%0d checks=%0d taken=%0d not_taken=%0d jumps=%0d stalls=%0d loads=%0d stores=%0d",
                 seed, random_blocks, program_words, randomizations, model_steps, scoreboard_checks,
                 branches_taken, branches_not_taken, jumps_seen, stalls_seen, loads_seen, stores_seen);
        $finish;
    end
endmodule
