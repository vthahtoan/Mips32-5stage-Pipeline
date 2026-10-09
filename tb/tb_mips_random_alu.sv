`timescale 1ns/1ps
module tb_mips_random_alu;
    import mips_instruction_pkg::*;
    import mips_reference_pkg::*;
    import mips_scoreboard_pkg::*;
    import mips_random_pkg::*;
    mips_random_instruction generator;
    mips_reference_model ref_model;
    mips_scoreboard scoreboard;
    logic clk = 0, pcreset = 0;
    logic [31:0] writeback, pc_out;
    logic [4:0] rd;
    logic enwrite;
    integer seed = 1;
    integer random_words = 64;
    integer program_words = 0, randomizations = 0, model_steps = 0;
    integer writes_seen = 0, stalls_seen = 0;
    integer branches_taken = 0, branches_not_taken = 0, jumps_seen = 0;
    integer signal_errors = 0;
    integer scoreboard_checks = 0, scoreboard_errors = 0;
    string scoreboard_first_failure = "";
    integer test_completed = 0;
    bit [16:0] loaded_kinds = 0;
    toplevel uut (
        .clk(clk), .pcreset(pcreset),
        .writeback(writeback), .pc_out(pc_out), .rd(rd), .enwrite(enwrite)
    );
    always #5 clk = ~clk;
    always @(posedge clk) begin
        if (pcreset) begin
            if ((^{uut.pcwrite, enwrite, uut.id_ex_branch, uut.id_ex_bne,
                   uut.ex_flush, uut.jump}) === 1'bx) begin
                signal_errors++;
                $display("RANDOM SIGNAL FAIL: seed=%0d time=%0t unknown control", seed, $time);
            end
            if (enwrite === 1'b1 &&
                ((^rd) === 1'bx || (rd != 0 && (^writeback) === 1'bx))) begin
                signal_errors++;
                $display("RANDOM SIGNAL FAIL: seed=%0d time=%0t unknown writeback", seed, $time);
            end
            if (uut.pcwrite === 1'b0) stalls_seen++;
            if (enwrite === 1'b1 && rd != 0) writes_seen++;
            if (uut.id_ex_branch === 1'b1 || uut.id_ex_bne === 1'b1) begin
                if (uut.ex_flush === 1'b1) branches_taken++;
                else if (uut.ex_flush === 1'b0) branches_not_taken++;
            end
            if (uut.jump === 1'b1 && uut.pcwrite === 1'b1 &&
                uut.ex_flush === 1'b0) jumps_seen++;
        end
    end
    task automatic load_generated_instruction();
        bit [31:0] machine_code;
        machine_code = generator.encode();
        uut.imem1.mem[program_words] = machine_code;
        ref_model.imem[program_words] = machine_code;
        loaded_kinds[generator.kind] = 1'b1;
        $display("RANDOM LOAD: seed=%0d index=%0d code=%08h kind=%s rs=%0d rt=%0d rd=%0d imm=%04h shamt=%0d",
                 seed, program_words, machine_code, generator.kind.name(),
                 generator.rs, generator.rt, generator.rd, generator.imm, generator.shamt);
        program_words++;
    endtask
    task automatic sample_final_state();
        for (int r = 0; r < 32; r++)
            scoreboard.check_register(r, uut.rf1.register[r]);
        for (int m = 0; m < 256; m++)
            scoreboard.check_memory(m, uut.mem1.dmem[m]);
        scoreboard.check_counts(writes_seen, stalls_seen, branches_taken,
                                branches_not_taken, jumps_seen);
        scoreboard_checks = scoreboard.checks;
        scoreboard_errors = scoreboard.errors;
        scoreboard_first_failure = scoreboard.first_failure;
    endtask
    initial begin
        if ($value$plusargs("SEED=%d", seed)) begin end
        if ($value$plusargs("RANDOM_WORDS=%d", random_words)) begin end
        if (seed < 1) $fatal(1, "SEED must be a positive signed 32-bit integer");
        if (random_words < 1 || random_words > 160)
            $fatal(1, "RANDOM_WORDS must be between 1 and 160");
        ref_model = new();
        generator = new();
        generator.srandom(seed);
        #1;
        for (int m = 0; m < 256; m++) begin
            uut.imem1.mem[m] = 0;
            uut.mem1.dmem[m] = 0;
        end
        for (int seed_register = 1; seed_register < 32; seed_register++) begin
            if (!generator.randomize() with {
                kind == MIPS_ADDI;
                rs == 0;
                rt == seed_register[4:0];
            }) $fatal(1, "Initializer randomize failed: seed=%0d register=%0d", seed, seed_register);
            randomizations++;
            load_generated_instruction();
        end
        repeat (random_words) begin
            if (!generator.randomize())
                $fatal(1, "ALU randomize failed: seed=%0d index=%0d", seed, program_words);
            randomizations++;
            load_generated_instruction();
        end
        ref_model.run(program_words);
        model_steps = ref_model.steps;
        scoreboard = new(ref_model, 0);
        repeat (3) @(negedge clk);
        pcreset = 1;
        repeat (program_words + 8) @(negedge clk);
        sample_final_state();
        if (signal_errors != 0 || scoreboard_errors != 0 ||
            scoreboard_checks != 293 || model_steps != program_words ||
            randomizations != program_words)
            $fatal(1, "RANDOM ALU FAIL: seed=%0d signals=%0d scoreboard=%0d first=%s",
                   seed, signal_errors, scoreboard_errors, scoreboard_first_failure);
        test_completed = 1;
        $display("RANDOM ALU TEST PASS: seed=%0d program_words=%0d random_words=%0d randomizations=%0d model_steps=%0d checks=%0d writes=%0d stalls=%0d",
                 seed, program_words, random_words, randomizations, model_steps,
                 scoreboard_checks, writes_seen, stalls_seen);
        $finish;
    end
endmodule
