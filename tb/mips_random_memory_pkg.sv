package mips_random_memory_pkg;
    typedef enum {MEM_LOAD_USE_RS, MEM_LOAD_STORE_DATA,
                  MEM_LOAD_ONE_GAP, MEM_LOAD_ZERO} memory_scenario_t;
    class mips_random_memory_scenario;
        rand memory_scenario_t scenario;
        rand bit [4:0] source_reg, load_reg, result_reg;
        rand bit [7:0] word_index;
        constraint legal_scenario {
            scenario inside {MEM_LOAD_USE_RS, MEM_LOAD_STORE_DATA,
                             MEM_LOAD_ONE_GAP, MEM_LOAD_ZERO};
        }
        constraint separate_registers {
            source_reg inside {[1:30]};
            load_reg inside {[1:30]};
            result_reg inside {[1:30]};
            source_reg != load_reg;
            source_reg != result_reg;
            load_reg != result_reg;
        }
        constraint varied_addresses {
            word_index dist {8'd0 := 2, 8'd1 := 2, 8'd127 := 2,
                             8'd128 := 2, 8'd254 := 2, 8'd255 := 2,
                             [8'd2:8'd126] :/ 6, [8'd129:8'd253] :/ 6};
        }
        function bit [15:0] offset(input bit second_word = 0);
            integer index_value, signed_offset;
            index_value = int'(word_index);
            if (second_word) index_value = index_value ^ 1;
            signed_offset = index_value * 4 - 512;
            return signed_offset[15:0];
        endfunction
    endclass
endpackage
