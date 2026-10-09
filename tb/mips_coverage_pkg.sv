package mips_coverage_pkg;
    import mips_instruction_pkg::*;
    function automatic instruction_kind_t decode_kind(input logic [31:0] instruction);
        if ((^instruction) === 1'bx) return instruction_kind_t'(-1);
        case (instruction[31:26])
            6'h08: return MIPS_ADDI;
            6'h0c: return MIPS_ANDI;
            6'h0d: return MIPS_ORI;
            6'h2b: return MIPS_SW;
            6'h23: return MIPS_LW;
            6'h04: return MIPS_BEQ;
            6'h05: return MIPS_BNE;
            6'h02: return MIPS_J;
            6'h00: case (instruction[5:0])
                6'h20: return MIPS_ADD;
                6'h22: return MIPS_SUB;
                6'h24: return MIPS_AND;
                6'h25: return MIPS_OR;
                6'h27: return MIPS_NOR;
                6'h26: return MIPS_XOR;
                6'h2a: return MIPS_SLT;
                6'h00: return MIPS_SLL;
                6'h02: return MIPS_SRL;
                default: return instruction_kind_t'(-1);
            endcase
            default: return instruction_kind_t'(-1);
        endcase
    endfunction
    function automatic bit uses_rs(input instruction_kind_t kind);
        return kind inside {MIPS_ADDI, MIPS_ANDI, MIPS_ORI, MIPS_SW, MIPS_LW,
                            MIPS_ADD, MIPS_SUB, MIPS_AND, MIPS_OR, MIPS_NOR,
                            MIPS_XOR, MIPS_SLT, MIPS_BEQ, MIPS_BNE};
    endfunction
    function automatic bit uses_rt(input instruction_kind_t kind);
        return kind inside {MIPS_SW, MIPS_ADD, MIPS_SUB, MIPS_AND, MIPS_OR,
                            MIPS_NOR, MIPS_XOR, MIPS_SLT, MIPS_SLL, MIPS_SRL,
                            MIPS_BEQ, MIPS_BNE};
    endfunction
    class mips_functional_coverage;
        bit [31:0] instruction_mask = 0, immediate_mask = 0, shift_mask = 0;
        bit [31:0] destination_mask = 0, memory_address_mask = 0, memory_offset_mask = 0;
        bit [31:0] load_destination_mask = 0, branch_outcome_mask = 0;
        bit [31:0] branch_direction_mask = 0, jump_mask = 0, hazard_mask = 0;
        bit [31:0] forwarding_mask = 0, load_distance_mask = 0;
        covergroup instruction_cg with function sample(integer kind);
            option.per_instance = 1;
            cp_kind: coverpoint kind { bins kinds[] = {[0:16]}; }
        endgroup
        covergroup immediate_cg with function sample(integer value_class);
            option.per_instance = 1;
            cp_value: coverpoint value_class {
                bins zero = {0}; bins one = {1}; bins max_positive = {2};
                bins min_negative = {3}; bins all_ones = {4}; bins other = {5};
            }
        endgroup
        covergroup shift_cg with function sample(integer operation, integer amount_class);
            option.per_instance = 1;
            cp_operation: coverpoint operation { bins sll = {0}; bins srl = {1}; }
            cp_amount: coverpoint amount_class { bins zero = {0}; bins middle = {1}; bins thirty_one = {2}; }
            operation_x_amount: cross cp_operation, cp_amount;
        endgroup
        covergroup destination_cg with function sample(integer is_zero);
            option.per_instance = 1;
            cp_destination: coverpoint is_zero { bins nonzero = {0}; bins zero = {1}; }
        endgroup
        covergroup memory_cg with function sample(integer operation, integer address_class, integer offset_class);
            option.per_instance = 1;
            cp_operation: coverpoint operation { bins lw = {0}; bins sw = {1}; }
            cp_address: coverpoint address_class { bins first = {0}; bins interior = {1}; bins last = {2}; }
            cp_offset: coverpoint offset_class { bins negative = {0}; bins zero = {1}; bins positive = {2}; }
            operation_x_address: cross cp_operation, cp_address;
            operation_x_offset: cross cp_operation, cp_offset;
        endgroup
        covergroup load_destination_cg with function sample(integer is_zero);
            option.per_instance = 1;
            cp_destination: coverpoint is_zero { bins nonzero = {0}; bins zero = {1}; }
        endgroup
        covergroup branch_cg with function sample(integer operation, integer taken, integer backwards);
            option.per_instance = 1;
            cp_operation: coverpoint operation { bins beq = {0}; bins bne = {1}; }
            cp_taken: coverpoint taken { bins not_taken = {0}; bins taken = {1}; }
            cp_direction: coverpoint backwards { bins forward_or_zero = {0}; bins backward = {1}; }
            operation_x_outcome: cross cp_operation, cp_taken;
        endgroup
        covergroup jump_cg with function sample(integer cancelled);
            option.per_instance = 1;
            cp_jump: coverpoint cancelled { bins accepted = {0}; bins cancelled_by_branch = {1}; }
        endgroup
        covergroup hazard_cg with function sample(integer consumer);
            option.per_instance = 1;
            cp_consumer: coverpoint consumer { bins alu = {0}; bins store_data = {1}; bins branch = {2}; }
        endgroup
        covergroup forwarding_cg with function sample(integer operand, integer source);
            option.per_instance = 1;
            cp_operand: coverpoint operand { bins a = {0}; bins b = {1}; }
            cp_source: coverpoint source { bins register_file = {0}; bins ex_mem = {1}; bins mem_wb = {2}; }
            operand_x_source: cross cp_operand, cp_source;
        endgroup
        covergroup load_distance_cg with function sample(integer distance);
            option.per_instance = 1;
            cp_distance: coverpoint distance { bins immediate = {1}; bins one_instruction_gap = {2}; }
        endgroup
        function new();
            instruction_cg = new(); immediate_cg = new(); shift_cg = new();
            destination_cg = new(); memory_cg = new(); load_destination_cg = new();
            branch_cg = new(); jump_cg = new(); hazard_cg = new();
            forwarding_cg = new(); load_distance_cg = new();
            instruction_cg.set_inst_name("instructions");
            immediate_cg.set_inst_name("immediates"); shift_cg.set_inst_name("shifts");
            destination_cg.set_inst_name("destinations"); memory_cg.set_inst_name("memory");
            load_destination_cg.set_inst_name("load_destinations"); branch_cg.set_inst_name("branches");
            jump_cg.set_inst_name("jumps"); hazard_cg.set_inst_name("load_use_hazards");
            forwarding_cg.set_inst_name("forwarding"); load_distance_cg.set_inst_name("load_distances");
        endfunction
        function void sample_instruction(input instruction_kind_t kind);
            instruction_cg.sample(kind);
            instruction_mask[kind] = 1;
        endfunction
        function void sample_destination(input bit is_zero, input bit is_load);
            destination_cg.sample(int'(is_zero));
            destination_mask[is_zero] = 1;
            if (is_load) begin
                load_destination_cg.sample(int'(is_zero));
                load_destination_mask[is_zero] = 1;
            end
        endfunction
        function void sample_immediate(input bit [15:0] immediate);
            integer value_class;
            case (immediate)
                16'h0000: value_class = 0;
                16'h0001: value_class = 1;
                16'h7fff: value_class = 2;
                16'h8000: value_class = 3;
                16'hffff: value_class = 4;
                default: value_class = 5;
            endcase
            immediate_cg.sample(value_class);
            immediate_mask[value_class] = 1;
        endfunction
        function void sample_shift(input instruction_kind_t kind, input bit [4:0] amount);
            integer operation, amount_class;
            operation = (kind == MIPS_SLL) ? 0 : 1;
            amount_class = (amount == 0) ? 0 : (amount == 31) ? 2 : 1;
            shift_cg.sample(operation, amount_class);
            shift_mask[operation*3 + amount_class] = 1;
        endfunction
        function void sample_memory(input instruction_kind_t kind, input bit [31:0] address, input bit [15:0] immediate);
            integer operation, address_class, offset_class;
            operation = (kind == MIPS_LW) ? 0 : 1;
            address_class = (address == 0) ? 0 : (address == 1020) ? 2 : 1;
            offset_class = (immediate == 0) ? 1 : immediate[15] ? 0 : 2;
            memory_cg.sample(operation, address_class, offset_class);
            memory_address_mask[operation*3 + address_class] = 1;
            memory_offset_mask[operation*3 + offset_class] = 1;
        endfunction
        function void sample_branch(input instruction_kind_t kind, input bit taken, input bit backwards);
            integer operation;
            operation = (kind == MIPS_BEQ) ? 0 : 1;
            sample_instruction(kind);
            branch_cg.sample(operation, int'(taken), int'(backwards));
            branch_outcome_mask[operation*2 + int'(taken)] = 1;
            branch_direction_mask[backwards] = 1;
        endfunction
        function void sample_jump(input bit cancelled);
            jump_cg.sample(int'(cancelled));
            jump_mask[cancelled] = 1;
            if (!cancelled) sample_instruction(MIPS_J);
        endfunction
        function void sample_hazard(input integer consumer);
            hazard_cg.sample(consumer);
            hazard_mask[consumer] = 1;
        endfunction
        function void sample_forwarding(input integer operand, input integer source);
            forwarding_cg.sample(operand, source);
            forwarding_mask[operand*3 + source] = 1;
        endfunction
        function void sample_load_distance(input integer distance);
            load_distance_cg.sample(distance);
            load_distance_mask[distance-1] = 1;
        endfunction
    endclass
endpackage
