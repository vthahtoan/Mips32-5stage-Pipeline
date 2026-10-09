package mips_scoreboard_pkg;
    import mips_reference_pkg::*;
    class mips_scoreboard;
        mips_reference_model expected_model;
        integer expected_stalls;
        integer checks;
        integer errors;
        string first_failure;
        function new(mips_reference_model expected_model,
                     integer expected_stalls);
            if (expected_model == null)
                $fatal(1, "Scoreboard requires a reference model");
            if ((^expected_stalls) === 1'bx || expected_stalls < 0)
                $fatal(1, "Scoreboard requires a nonnegative stall expectation");
            this.expected_model = expected_model;
            this.expected_stalls = expected_stalls;
            checks = 0;
            errors = 0;
            first_failure = "";
        endfunction
        function void check_word(logic [31:0] actual,
                                 logic [31:0] expected, string label);
            checks++;
            if (actual !== expected) begin
                errors++;
                if (errors == 1)
                    first_failure = $sformatf("%s: expected=%08h actual=%08h",
                                             label, expected, actual);
                $display("SCOREBOARD FAIL %s: expected=%08h actual=%08h",
                         label, expected, actual);
            end
        endfunction
        function void check_register(integer index, logic [31:0] actual);
            if (index < 0 || index >= 32)
                $fatal(1, "Scoreboard invalid register index: %0d", index);
            check_word(actual, expected_model.regs[index],
                       $sformatf("CPU r%0d", index));
        endfunction
        function void check_memory(integer index, logic [31:0] actual);
            if (index < 0 || index >= 256)
                $fatal(1, "Scoreboard invalid memory index: %0d", index);
            check_word(actual, expected_model.dmem[index],
                       $sformatf("CPU memory byte %0d", index*4));
        endfunction
        function void check_counts(integer writes_seen, integer stalls_seen,
                                   integer branches_taken,
                                   integer branches_not_taken, integer jumps_seen);
            check_word(writes_seen, expected_model.write_count, "CPU register write count");
            check_word(stalls_seen, expected_stalls, "CPU stall count");
            check_word(branches_taken, expected_model.branches_taken, "CPU taken branches");
            check_word(branches_not_taken, expected_model.branches_not_taken, "CPU not-taken branches");
            check_word(jumps_seen, expected_model.jumps, "CPU accepted jumps");
        endfunction
    endclass
endpackage
