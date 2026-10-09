`timescale 1ns/1ps
module tb_mips_random_memory;
    import mips_instruction_pkg::*;
    import mips_reference_pkg::*;
    import mips_scoreboard_pkg::*;
    import mips_random_pkg::*;
    import mips_random_memory_pkg::*;
    mips_random_instruction initializer;
    mips_random_memory_scenario generator;
    mips_reference_model ref_model;
    mips_scoreboard scoreboard;
    logic clk = 0, pcreset = 0;
    logic [31:0] writeback, pc_out;
    logic [4:0] rd;
    logic enwrite;
    integer seed = 1, random_blocks = 16;
    integer program_words = 0, randomizations = 0, model_steps = 0;
    integer expected_stalls = 0, expected_loads = 0, expected_stores = 0;
    integer writes_seen = 0, stalls_seen = 0, loads_seen = 0, stores_seen = 0;
    integer branches_taken = 0, branches_not_taken = 0, jumps_seen = 0;
    integer scenario_counts [0:3] = '{default:0};
    bit [31:0] loaded_scenarios = 0;
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
                $display("MEMORY SIGNAL FAIL: seed=%0d time=%0t unknown control", seed, $time);
            end
            if (enwrite === 1'b1 &&
                ((^rd) === 1'bx || (rd != 0 && (^writeback) === 1'bx))) begin
                signal_errors++;
                $display("MEMORY SIGNAL FAIL: seed=%0d time=%0t unknown writeback", seed, $time);
            end
            if (uut.ex_mem_memread === 1'b1 || uut.ex_mem_memwrite === 1'b1) begin
                if ((^uut.ex_mem_result) === 1'bx ||
                    uut.ex_mem_result[1:0] !== 2'b00 || uut.ex_mem_result >= 32'd1024) begin
                    signal_errors++;
                    $display("MEMORY SIGNAL FAIL: seed=%0d time=%0t invalid address=%08h",
                             seed, $time, uut.ex_mem_result);
                end
                if (uut.ex_mem_memwrite === 1'b1 && (^uut.ex_mem_writedata) === 1'bx) begin
                    signal_errors++;
                    $display("MEMORY SIGNAL FAIL: seed=%0d time=%0t unknown store data", seed, $time);
                end
                if (uut.ex_mem_memread === 1'b1 && (^uut.memdata) === 1'bx) begin
                    signal_errors++;
                    $display("MEMORY SIGNAL FAIL: seed=%0d time=%0t unknown load data", seed, $time);
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
                                      input bit [15:0] immediate);
        mips_instruction instruction;
        bit [31:0] machine_code;
        if (program_words >= 256) $fatal(1, "Memory test program exceeds IMEM");
        instruction = new(kind, rs, rt, destination, immediate);
        machine_code = instruction.encode();
        uut.imem1.mem[program_words] = machine_code;
        ref_model.imem[program_words] = machine_code;
        if (kind == MIPS_LW) expected_loads++;
        if (kind == MIPS_SW) expected_stores++;
        $display("MEMORY LOAD: seed=%0d index=%0d code=%08h kind=%s rs=%0d rt=%0d rd=%0d imm=%04h",
                 seed, program_words, machine_code, kind.name(), rs, rt, destination, immediate);
        program_words++;
    endtask
    task automatic append_scenario();
        bit [4:0] source_reg, load_reg, result_reg;
        bit [15:0] first_offset, second_offset;
        source_reg = generator.source_reg;
        load_reg = generator.load_reg;
        result_reg = generator.result_reg;
        first_offset = generator.offset();
        second_offset = generator.offset(1);
        $display("MEMORY BLOCK: seed=%0d start=%0d scenario=%s word=%0d source=r%0d load=r%0d result=r%0d",
                 seed, program_words, generator.scenario.name(), generator.word_index,
                 source_reg, load_reg, result_reg);
        scenario_counts[generator.scenario]++;
        loaded_scenarios[generator.scenario] = 1;
        case (generator.scenario)
            MEM_LOAD_USE_RS: begin
                append_instruction(MIPS_SW, 31, source_reg, 0, first_offset);
                append_instruction(MIPS_LW, 31, load_reg, 0, first_offset);
                append_instruction(MIPS_ADD, load_reg, source_reg, result_reg, 0);
                append_instruction(MIPS_SW, 31, result_reg, 0, first_offset);
                append_instruction(MIPS_LW, 31, load_reg, 0, first_offset);
                append_instruction(MIPS_XOR, source_reg, load_reg, result_reg, 0);
                expected_stalls += 2;
            end
            MEM_LOAD_STORE_DATA: begin
                append_instruction(MIPS_SW, 31, source_reg, 0, first_offset);
                append_instruction(MIPS_LW, 31, load_reg, 0, first_offset);
                append_instruction(MIPS_SW, 31, load_reg, 0, second_offset);
                append_instruction(MIPS_LW, 31, result_reg, 0, second_offset);
                append_instruction(MIPS_ADD, result_reg, source_reg, load_reg, 0);
                append_instruction(MIPS_SW, 31, load_reg, 0, first_offset);
                expected_stalls += 2;
            end
            MEM_LOAD_ONE_GAP: begin
                append_instruction(MIPS_SW, 31, source_reg, 0, first_offset);
                append_instruction(MIPS_LW, 31, load_reg, 0, first_offset);
                append_instruction(MIPS_ADD, source_reg, source_reg, result_reg, 0);
                append_instruction(MIPS_XOR, load_reg, source_reg, result_reg, 0);
                append_instruction(MIPS_SW, 31, result_reg, 0, second_offset);
                append_instruction(MIPS_OR, source_reg, load_reg, result_reg, 0);
            end
            MEM_LOAD_ZERO: begin
                append_instruction(MIPS_SW, 31, source_reg, 0, first_offset);
                append_instruction(MIPS_LW, 31, 0, 0, first_offset);
                append_instruction(MIPS_ADD, 0, source_reg, result_reg, 0);
                append_instruction(MIPS_SW, 31, result_reg, 0, second_offset);
                append_instruction(MIPS_LW, 31, load_reg, 0, second_offset);
                append_instruction(MIPS_SW, 31, load_reg, 0, first_offset);
                expected_stalls += 1;
            end
            default: $fatal(1, "Invalid memory scenario");
        endcase
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
        if (random_blocks < 4 || random_blocks > 24)
            $fatal(1, "RANDOM_BLOCKS must be between 4 and 24");
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
            if (!initializer.randomize() with { kind == MIPS_ADDI; rs == 0; rt == r[4:0]; })
                $fatal(1, "Memory initializer failed: seed=%0d register=%0d", seed, r);
            randomizations++;
            append_instruction(initializer.kind, initializer.rs, initializer.rt, 0, initializer.imm);
        end
        if (!initializer.randomize() with {kind == MIPS_ADDI; rs == 0; rt == 31; imm == 16'd512;})
            $fatal(1, "Memory base initializer failed: seed=%0d", seed);
        randomizations++;
        append_instruction(initializer.kind, initializer.rs, initializer.rt, 0, initializer.imm);
        for (int block_index = 0; block_index < random_blocks; block_index++) begin
            if (block_index < 4) begin
                if (!generator.randomize() with {int'(scenario) == block_index;})
                    $fatal(1, "Memory scenario initializer failed: seed=%0d block=%0d", seed, block_index);
            end else if (!generator.randomize())
                $fatal(1, "Memory randomize failed: seed=%0d block=%0d", seed, block_index);
            randomizations++;
            append_scenario();
        end
        ref_model.run(program_words);
        model_steps = ref_model.steps;
        scoreboard = new(ref_model, expected_stalls);
        repeat (3) @(negedge clk);
        pcreset = 1;
        repeat (program_words + expected_stalls + 8) @(negedge clk);
        sample_final_state();
        if (signal_errors != 0 || scoreboard_errors != 0 || scoreboard_checks != 295 ||
            model_steps != program_words || program_words != 31 + 6*random_blocks ||
            randomizations != 31 + random_blocks || loaded_scenarios != 4'b1111)
            $fatal(1, "RANDOM MEMORY FAIL: seed=%0d signals=%0d scoreboard=%0d first=%s",
                   seed, signal_errors, scoreboard_errors, scoreboard_first_failure);
        test_completed = 1;
        $display("RANDOM MEMORY TEST PASS: seed=%0d blocks=%0d words=%0d randomizations=%0d model_steps=%0d checks=%0d loads=%0d stores=%0d stalls=%0d expected_stalls=%0d",
                 seed, random_blocks, program_words, randomizations, model_steps,
                 scoreboard_checks, loads_seen, stores_seen, stalls_seen, expected_stalls);
        $finish;
    end
endmodule
