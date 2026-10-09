`timescale 1ns/1ps
module mips_coverage_monitor (
    input logic clk, active,
    input integer program_words,
    input logic [31:0] wb_pc, mem_pc, ex_pc, id_pc,
    input logic [31:0] wb_instruction, mem_instruction, ex_instruction, id_instruction,
    input logic wb_write,
    input logic [4:0] wb_rd, ex_rd,
    input logic mem_read, mem_write,
    input logic [31:0] memory_address,
    input logic ex_regwrite, ex_load, ex_store, ex_branch, ex_bne,
    input logic taken, id_jump, pcwrite,
    input logic [1:0] sela, selb
);
    import mips_instruction_pkg::*;
    import mips_coverage_pkg::*;
    mips_functional_coverage collector;
    integer instruction_mask = 0, immediate_mask = 0, shift_mask = 0;
    integer destination_mask = 0, memory_address_mask = 0, memory_offset_mask = 0;
    integer load_destination_mask = 0, branch_outcome_mask = 0;
    integer branch_direction_mask = 0, jump_mask = 0, hazard_mask = 0;
    integer forwarding_mask = 0, load_distance_mask = 0;
    integer monitor_errors = 0, sampled_events = 0;
    instruction_kind_t wb_kind, mem_kind, ex_kind, id_kind;
    integer distance;
    bit ex_active;
    initial collector = new();
    function automatic bit valid_pc(input logic [31:0] pc_plus_four);
        return ((^pc_plus_four) !== 1'bx) && pc_plus_four >= 4 &&
               pc_plus_four[1:0] == 0 && pc_plus_four <= $unsigned(program_words)*4;
    endfunction
    task automatic bad_sample(input string label);
        monitor_errors++;
        $display("COVERAGE MONITOR FAIL: time=%0t %s", $time, label);
    endtask
    always @(posedge clk) begin
        if (active) begin
            wb_kind = valid_pc(wb_pc) ? decode_kind(wb_instruction) : instruction_kind_t'(-1);
            mem_kind = valid_pc(mem_pc) ? decode_kind(mem_instruction) : instruction_kind_t'(-1);
            ex_kind = valid_pc(ex_pc) ? decode_kind(ex_instruction) : instruction_kind_t'(-1);
            id_kind = valid_pc(id_pc) ? decode_kind(id_instruction) : instruction_kind_t'(-1);
            ex_active = (ex_regwrite === 1'b1 || ex_load === 1'b1 || ex_store === 1'b1 ||
                         ex_branch === 1'b1 || ex_bne === 1'b1);
            if (wb_write === 1'b1 && valid_pc(wb_pc)) begin
                if (wb_kind inside {MIPS_ADDI, MIPS_ANDI, MIPS_ORI, MIPS_LW,
                                    MIPS_ADD, MIPS_SUB, MIPS_AND, MIPS_OR, MIPS_NOR,
                                    MIPS_XOR, MIPS_SLT, MIPS_SLL, MIPS_SRL} &&
                    (^wb_rd) !== 1'bx) begin
                    collector.sample_instruction(wb_kind);
                    collector.sample_destination(wb_rd == 0, wb_kind == MIPS_LW);
                    sampled_events++;
                    if (wb_kind inside {MIPS_ADDI, MIPS_ANDI, MIPS_ORI})
                        collector.sample_immediate(wb_instruction[15:0]);
                    if (wb_kind inside {MIPS_SLL, MIPS_SRL})
                        collector.sample_shift(wb_kind, wb_instruction[10:6]);
                end else bad_sample("WB instruction/control mismatch");
            end
            if ((mem_read === 1'b1 || mem_write === 1'b1) && valid_pc(mem_pc)) begin
                if ((^memory_address) === 1'bx || memory_address[1:0] !== 0 ||
                    memory_address >= 1024) bad_sample("invalid memory address");
                else if ((mem_kind == MIPS_LW && mem_read === 1'b1 && mem_write === 1'b0) ||
                         (mem_kind == MIPS_SW && mem_write === 1'b1 && mem_read === 1'b0)) begin
                    collector.sample_memory(mem_kind, memory_address, mem_instruction[15:0]);
                    if (mem_kind == MIPS_SW) begin
                        collector.sample_instruction(MIPS_SW);
                        sampled_events++;
                    end
                end else bad_sample("MEM instruction/control mismatch");
            end
            if ((ex_branch === 1'b1 || ex_bne === 1'b1) && valid_pc(ex_pc)) begin
                if ((ex_kind == MIPS_BEQ && ex_branch === 1'b1) ||
                    (ex_kind == MIPS_BNE && ex_bne === 1'b1)) begin
                    if (taken === 1'b0 || taken === 1'b1) begin
                        collector.sample_branch(ex_kind, taken, ex_instruction[15]);
                        sampled_events++;
                    end else bad_sample("unknown branch outcome");
                end else bad_sample("EX branch instruction/control mismatch");
            end
            if (id_jump === 1'b1 && pcwrite === 1'b1 && valid_pc(id_pc)) begin
                if (id_kind != MIPS_J) bad_sample("ID jump instruction/control mismatch");
                else if (taken === 1'b0 || taken === 1'b1) begin
                    collector.sample_jump(taken);
                    if (!taken) sampled_events++;
                end else bad_sample("unknown jump cancellation");
            end
            if (pcwrite === 1'b0 && ex_load === 1'b1 && ex_rd != 0 && valid_pc(id_pc)) begin
                if (id_kind == MIPS_SW && id_instruction[20:16] == ex_rd)
                    collector.sample_hazard(1);
                else if (id_kind inside {MIPS_BEQ, MIPS_BNE}) collector.sample_hazard(2);
                else if (id_kind inside {MIPS_ADDI, MIPS_ANDI, MIPS_ORI,
                                        MIPS_ADD, MIPS_SUB, MIPS_AND, MIPS_OR, MIPS_NOR,
                                        MIPS_XOR, MIPS_SLT, MIPS_SLL, MIPS_SRL})
                    collector.sample_hazard(0);
            end
            if (ex_active && valid_pc(ex_pc) && ex_kind != instruction_kind_t'(-1)) begin
                if (uses_rs(ex_kind)) begin
                    if ((^sela) === 1'bx || sela > 2) bad_sample("invalid forwarding A");
                    else collector.sample_forwarding(0, int'(sela));
                end
                if (uses_rt(ex_kind)) begin
                    if ((^selb) === 1'bx || selb > 2) bad_sample("invalid forwarding B");
                    else collector.sample_forwarding(1, int'(selb));
                end
                if (wb_kind == MIPS_LW && wb_write === 1'b1 && wb_rd != 0 &&
                    ((uses_rs(ex_kind) && ex_instruction[25:21] == wb_rd && sela === 2'd2) ||
                     (uses_rt(ex_kind) && ex_instruction[20:16] == wb_rd && selb === 2'd2))) begin
                    distance = int'((ex_pc - wb_pc) >> 2);
                    if (distance inside {1, 2}) collector.sample_load_distance(distance);
                end
            end
            instruction_mask = int'(collector.instruction_mask);
            immediate_mask = int'(collector.immediate_mask);
            shift_mask = int'(collector.shift_mask);
            destination_mask = int'(collector.destination_mask);
            memory_address_mask = int'(collector.memory_address_mask);
            memory_offset_mask = int'(collector.memory_offset_mask);
            load_destination_mask = int'(collector.load_destination_mask);
            branch_outcome_mask = int'(collector.branch_outcome_mask);
            branch_direction_mask = int'(collector.branch_direction_mask);
            jump_mask = int'(collector.jump_mask);
            hazard_mask = int'(collector.hazard_mask);
            forwarding_mask = int'(collector.forwarding_mask);
            load_distance_mask = int'(collector.load_distance_mask);
        end
    end
endmodule
