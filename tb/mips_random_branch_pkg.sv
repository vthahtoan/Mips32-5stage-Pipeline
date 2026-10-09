package mips_random_branch_pkg;
    typedef enum {CF_BEQ_TAKEN, CF_BEQ_NOT_TAKEN,
                  CF_BNE_TAKEN, CF_BNE_NOT_TAKEN,
                  CF_JUMP_FORWARD, CF_BOUNDED_LOOP,
                  CF_LOAD_BRANCH, CF_BRANCH_OVER_JUMP} branch_scenario_t;
    class mips_random_branch_scenario;
        rand branch_scenario_t scenario;
        rand bit [4:0] left_reg, right_reg, result_reg, counter_reg;
        rand bit [15:0] value, marker;
        rand bit [2:0] iterations;
        constraint valid_scenario {
            scenario inside {CF_BEQ_TAKEN, CF_BEQ_NOT_TAKEN,
                             CF_BNE_TAKEN, CF_BNE_NOT_TAKEN,
                             CF_JUMP_FORWARD, CF_BOUNDED_LOOP,
                             CF_LOAD_BRANCH, CF_BRANCH_OVER_JUMP};
        }
        constraint distinct_registers {
            left_reg inside {[1:30]};
            right_reg inside {[1:30]};
            result_reg inside {[1:30]};
            counter_reg inside {[1:30]};
            left_reg != right_reg;
            left_reg != result_reg;
            left_reg != counter_reg;
            right_reg != result_reg;
            right_reg != counter_reg;
            result_reg != counter_reg;
        }
        constraint values_and_loop_limit {
            value dist {16'h0001 := 2, 16'h7fff := 2,
                        16'h8000 := 2, 16'hffff := 2,
                        [16'h0002:16'h7ffe] :/ 4,
                        [16'h8001:16'hfffe] :/ 4};
            marker inside {[16'd1:16'd32767]};
            iterations inside {[1:4]};
        }
    endclass
endpackage
