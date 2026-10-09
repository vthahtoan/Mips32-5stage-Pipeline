`timescale 1ns/1ps
module tb_mips_scoreboard;
    import mips_instruction_pkg::*;
    import mips_reference_pkg::*;
    import mips_scoreboard_pkg::*;
    mips_scoreboard scoreboard;
    integer expected_stalls = 0;
    integer scoreboard_checks = 0, scoreboard_errors = 0;
    string scoreboard_first_failure = "";
    mips_reference_model ref_model;
    integer program_words = 0;
    integer model_errors = 0, model_checks = 0, model_steps = 0;
    logic clk = 0;
    logic pcreset = 0;
    logic [31:0] writeback, pc_out;
    logic [4:0] rd;
    logic enwrite;
    integer test_id = 0;
    integer errors = 0, encoder_checks = 0;
    integer writes_seen = 0, stalls_seen = 0;
    integer branches_taken = 0, branches_not_taken = 0, jumps_seen = 0;
    integer inject_dut_error = 0;
    integer i;
    bit [16:0] loaded_kinds = 0;
    toplevel uut (
        .clk(clk), .pcreset(pcreset),
        .writeback(writeback), .pc_out(pc_out), .rd(rd), .enwrite(enwrite)
    );
    always #5 clk = ~clk;
    always @(posedge clk) begin
        if (pcreset) begin
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
    task automatic check_model_word(
        input logic [31:0] actual,
        input logic [31:0] expected,
        input string label
    );
        model_checks++;
        if (actual !== expected) begin
            model_errors++;
            $display("MODEL FAIL %s: expected=%08h actual=%08h", label, expected, actual);
        end
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
    task automatic load_instruction(
        input integer index,
        input instruction_kind_t kind,
        input bit [4:0] rs, input bit [4:0] rt, input bit [4:0] rd,
        input bit [15:0] imm,
        input logic [31:0] expected_code,
        input bit [4:0] shamt = 0,
        input bit [25:0] target = 0
    );
        mips_instruction instr;
        bit [31:0] machine_code;
        instr = new(kind, rs, rt, rd, imm, shamt, target);
        machine_code = instr.encode();
        encoder_checks++;
        loaded_kinds[kind] = 1'b1;
        if (machine_code !== expected_code) begin
            errors++;
            $display("ENCODE FAIL index=%0d expected=%08h actual=%08h",
                     index, expected_code, machine_code);
        end
        uut.imem1.mem[index] = machine_code;
        ref_model.imem[index] = expected_code;
        if (index + 1 > program_words) program_words = index + 1;
    endtask
    initial begin
        ref_model = new();
        if ($value$plusargs("TEST=%d", test_id)) begin end
        if ($value$plusargs("INJECT_DUT_ERROR=%d", inject_dut_error)) begin end
        if (test_id < 0 || test_id > 2) $fatal(1, "TEST must be 0, 1 or 2");
        if (inject_dut_error < 0 || inject_dut_error > 2)
            $fatal(1, "INJECT_DUT_ERROR must be 0, 1 or 2");
        #1;
        for (i = 0; i < 256; i++) begin
            uut.imem1.mem[i] = 32'd0;
            uut.mem1.dmem[i] = 32'd0;
        end
        case (test_id)
            0: begin
                load_instruction(0, MIPS_ADDI, 0, 1, 0, 16'h0019, 32'h20010019);
                load_instruction(1, MIPS_ADDI, 0, 2, 0, 16'h0009, 32'h20020009);
                load_instruction(2, MIPS_ADD, 1, 2, 3, 16'h0000, 32'h00221820);
                load_instruction(3, MIPS_SUB, 1, 2, 4, 16'h0000, 32'h00222022);
                load_instruction(4, MIPS_AND, 1, 2, 5, 16'h0000, 32'h00222824);
                load_instruction(5, MIPS_OR, 1, 2, 6, 16'h0000, 32'h00223025);
                load_instruction(6, MIPS_NOR, 1, 2, 7, 16'h0000, 32'h00223827);
                load_instruction(7, MIPS_XOR, 1, 2, 8, 16'h0000, 32'h00224026);
                load_instruction(8, MIPS_SLT, 2, 1, 9, 16'h0000, 32'h0041482a);
                load_instruction(9, MIPS_SLT, 1, 2, 10, 16'h0000, 32'h0022502a);
                load_instruction(10, MIPS_SLL, 0, 2, 11, 16'h0000, 32'h00025880, 5'd2, 26'd0);
                load_instruction(11, MIPS_SRL, 0, 11, 12, 16'h0000, 32'h000b6042, 5'd1, 26'd0);
                load_instruction(12, MIPS_ADDI, 0, 13, 0, 16'hffff, 32'h200dffff);
                load_instruction(13, MIPS_ANDI, 13, 14, 0, 16'h8001, 32'h31ae8001);
                load_instruction(14, MIPS_ORI, 0, 15, 0, 16'h8000, 32'h340f8000);
                load_instruction(15, MIPS_SLT, 13, 15, 16, 16'h0000, 32'h01af802a);
                load_instruction(16, MIPS_SLT, 15, 13, 17, 16'h0000, 32'h01ed882a);
                load_instruction(17, MIPS_SRL, 0, 13, 18, 16'h0000, 32'h000d97c2, 5'd31, 26'd0);
                load_instruction(18, MIPS_SLL, 0, 18, 19, 16'h0000, 32'h00129fc0, 5'd31, 26'd0);
                load_instruction(19, MIPS_SLL, 0, 2, 20, 16'h0000, 32'h0002a000, 5'd0, 26'd0);
                load_instruction(20, MIPS_SRL, 0, 13, 21, 16'h0000, 32'h000da802, 5'd0, 26'd0);
                load_instruction(21, MIPS_SUB, 2, 1, 22, 16'h0000, 32'h0041b022);
                load_instruction(22, MIPS_ADDI, 0, 0, 0, 16'h0063, 32'h20000063);
                load_instruction(23, MIPS_ADDI, 0, 23, 0, 16'h0001, 32'h20170001);
                load_instruction(24, MIPS_ADDI, 0, 24, 0, 16'hfff6, 32'h2018fff6);
                load_instruction(25, MIPS_ADDI, 24, 24, 0, 16'h0003, 32'h23180003);
                load_instruction(26, MIPS_ADD, 24, 24, 25, 16'h0000, 32'h0318c820);
                load_instruction(27, MIPS_SLL, 0, 1, 26, 16'h0000, 32'h0001d0c0, 5'd3, 26'd0);
                load_instruction(28, MIPS_SRL, 0, 19, 27, 16'h0000, 32'h0013d902, 5'd4, 26'd0);
                load_instruction(29, MIPS_AND, 13, 15, 28, 16'h0000, 32'h01afe024);
                load_instruction(30, MIPS_OR, 14, 15, 29, 16'h0000, 32'h01cfe825);
                load_instruction(31, MIPS_NOR, 0, 0, 30, 16'h0000, 32'h0000f027);
                load_instruction(32, MIPS_XOR, 13, 13, 31, 16'h0000, 32'h01adf826);
            end
            1: begin
                expected_stalls = 4;
                load_instruction(0, MIPS_ADDI, 0, 1, 0, 16'h0040, 32'h20010040);
                load_instruction(1, MIPS_ADDI, 0, 2, 0, 16'h007b, 32'h2002007b);
                load_instruction(2, MIPS_SW, 1, 2, 0, 16'h0000, 32'hac220000);
                load_instruction(3, MIPS_LW, 1, 3, 0, 16'h0000, 32'h8c230000);
                load_instruction(4, MIPS_ADD, 3, 2, 4, 16'h0000, 32'h00622020);
                load_instruction(5, MIPS_SW, 1, 4, 0, 16'h0004, 32'hac240004);
                load_instruction(6, MIPS_ADDI, 0, 5, 0, 16'hfff6, 32'h2005fff6);
                load_instruction(7, MIPS_SW, 1, 5, 0, 16'h0008, 32'hac250008);
                load_instruction(8, MIPS_LW, 1, 6, 0, 16'h0008, 32'h8c260008);
                load_instruction(9, MIPS_SW, 1, 6, 0, 16'h000c, 32'hac26000c);
                load_instruction(10, MIPS_LW, 1, 7, 0, 16'h000c, 32'h8c27000c);
                load_instruction(11, MIPS_ADDI, 7, 8, 0, 16'h0003, 32'h20e80003);
                load_instruction(12, MIPS_SW, 1, 8, 0, 16'h0010, 32'hac280010);
                load_instruction(13, MIPS_LW, 1, 9, 0, 16'h0010, 32'h8c290010);
                load_instruction(14, MIPS_SW, 1, 2, 0, 16'hfffc, 32'hac22fffc);
                load_instruction(15, MIPS_LW, 1, 10, 0, 16'hfffc, 32'h8c2afffc);
                load_instruction(16, MIPS_ANDI, 10, 11, 0, 16'h000f, 32'h314b000f);
                load_instruction(17, MIPS_ADDI, 0, 12, 0, 16'h0000, 32'h200c0000);
                load_instruction(18, MIPS_SW, 1, 0, 0, 16'h0014, 32'hac200014);
                load_instruction(19, MIPS_LW, 1, 0, 0, 16'h0000, 32'h8c200000);
                load_instruction(20, MIPS_ADDI, 0, 13, 0, 16'h0007, 32'h200d0007);
                load_instruction(21, MIPS_ADD, 2, 13, 14, 16'h0000, 32'h004d7020);
            end
            2: begin
                expected_stalls = 1;
                uut.mem1.dmem[3] = 32'd7;
                ref_model.dmem[3] = 32'd7;
                load_instruction(0, MIPS_ADDI, 0, 1, 0, 16'h0007, 32'h20010007);
                load_instruction(1, MIPS_ADDI, 0, 2, 0, 16'h0007, 32'h20020007);
                load_instruction(2, MIPS_BEQ, 1, 2, 0, 16'h0002, 32'h10220002);
                load_instruction(3, MIPS_SW, 0, 1, 0, 16'h0000, 32'hac010000);
                load_instruction(4, MIPS_ADDI, 0, 10, 0, 16'h0063, 32'h200a0063);
                load_instruction(5, MIPS_ADDI, 0, 3, 0, 16'h000b, 32'h2003000b);
                load_instruction(6, MIPS_BNE, 1, 2, 0, 16'h0002, 32'h14220002);
                load_instruction(7, MIPS_ADDI, 0, 4, 0, 16'h000c, 32'h2004000c);
                load_instruction(8, MIPS_ADDI, 0, 2, 0, 16'h0008, 32'h20020008);
                load_instruction(9, MIPS_BNE, 1, 2, 0, 16'h0002, 32'h14220002);
                load_instruction(10, MIPS_SW, 0, 2, 0, 16'h0004, 32'hac020004);
                load_instruction(11, MIPS_ADDI, 0, 11, 0, 16'h0063, 32'h200b0063);
                load_instruction(12, MIPS_ADDI, 0, 5, 0, 16'h000d, 32'h2005000d);
                load_instruction(13, MIPS_BEQ, 1, 2, 0, 16'h0002, 32'h10220002);
                load_instruction(14, MIPS_ADDI, 0, 6, 0, 16'h000e, 32'h2006000e);
                load_instruction(15, MIPS_J, 0, 0, 0, 16'h0000, 32'h08000012, 5'd0, 26'd18);
                load_instruction(16, MIPS_SW, 0, 1, 0, 16'h0008, 32'hac010008);
                load_instruction(17, MIPS_ADDI, 0, 12, 0, 16'h0063, 32'h200c0063);
                load_instruction(18, MIPS_ADDI, 0, 7, 0, 16'h000f, 32'h2007000f);
                load_instruction(19, MIPS_ADDI, 0, 8, 0, 16'h0003, 32'h20080003);
                load_instruction(20, MIPS_ADDI, 8, 8, 0, 16'hffff, 32'h2108ffff);
                load_instruction(21, MIPS_BNE, 8, 0, 0, 16'hfffe, 32'h1500fffe);
                load_instruction(22, MIPS_ADDI, 0, 9, 0, 16'h0011, 32'h20090011);
                load_instruction(23, MIPS_LW, 0, 13, 0, 16'h000c, 32'h8c0d000c);
                load_instruction(24, MIPS_BEQ, 13, 1, 0, 16'h0002, 32'h11a10002);
                load_instruction(25, MIPS_SW, 0, 1, 0, 16'h0010, 32'hac010010);
                load_instruction(26, MIPS_ADDI, 0, 14, 0, 16'h0063, 32'h200e0063);
                load_instruction(27, MIPS_ADDI, 0, 15, 0, 16'h0012, 32'h200f0012);
                load_instruction(28, MIPS_BEQ, 0, 0, 0, 16'h0002, 32'h10000002);
                load_instruction(29, MIPS_J, 0, 0, 0, 16'h0000, 32'h08000022, 5'd0, 26'd34);
                load_instruction(30, MIPS_ADDI, 0, 16, 0, 16'h0063, 32'h20100063);
                load_instruction(31, MIPS_ADDI, 0, 17, 0, 16'h0013, 32'h20110013);
                load_instruction(32, MIPS_J, 0, 0, 0, 16'h0000, 32'h08000024, 5'd0, 26'd36);
                load_instruction(33, MIPS_ADDI, 0, 18, 0, 16'h0063, 32'h20120063);
                load_instruction(34, MIPS_ADDI, 0, 17, 0, 16'h0063, 32'h20110063);
                load_instruction(35, MIPS_SW, 0, 1, 0, 16'h0014, 32'hac010014);
                load_instruction(36, MIPS_ADDI, 0, 19, 0, 16'h0014, 32'h20130014);
            end
        endcase
        ref_model.run(program_words);
        model_steps = ref_model.steps;
        scoreboard = new(ref_model, expected_stalls);
        repeat (3) @(negedge clk);
        pcreset = 1;
        repeat (80) @(negedge clk);
        case (test_id)
            0: begin
                check_model_word(ref_model.regs[0], 32'h00000000, "r0");
                check_model_word(ref_model.regs[1], 32'h00000019, "r1");
                check_model_word(ref_model.regs[2], 32'h00000009, "r2");
                check_model_word(ref_model.regs[3], 32'd34, "r3");
                check_model_word(ref_model.regs[4], 32'h00000010, "r4");
                check_model_word(ref_model.regs[5], 32'h00000009, "r5");
                check_model_word(ref_model.regs[6], 32'h00000019, "r6");
                check_model_word(ref_model.regs[7], 32'hffffffe6, "r7");
                check_model_word(ref_model.regs[8], 32'h00000010, "r8");
                check_model_word(ref_model.regs[9], 32'h00000001, "r9");
                check_model_word(ref_model.regs[10], 32'h00000000, "r10");
                check_model_word(ref_model.regs[11], 32'h00000024, "r11");
                check_model_word(ref_model.regs[12], 32'h00000012, "r12");
                check_model_word(ref_model.regs[13], 32'hffffffff, "r13");
                check_model_word(ref_model.regs[14], 32'h00008001, "r14");
                check_model_word(ref_model.regs[15], 32'h00008000, "r15");
                check_model_word(ref_model.regs[16], 32'h00000001, "r16");
                check_model_word(ref_model.regs[17], 32'h00000000, "r17");
                check_model_word(ref_model.regs[18], 32'h00000001, "r18");
                check_model_word(ref_model.regs[19], 32'h80000000, "r19");
                check_model_word(ref_model.regs[20], 32'h00000009, "r20");
                check_model_word(ref_model.regs[21], 32'hffffffff, "r21");
                check_model_word(ref_model.regs[22], 32'hfffffff0, "r22");
                check_model_word(ref_model.regs[23], 32'h00000001, "r23");
                check_model_word(ref_model.regs[24], 32'hfffffff9, "r24");
                check_model_word(ref_model.regs[25], 32'hfffffff2, "r25");
                check_model_word(ref_model.regs[26], 32'h000000c8, "r26");
                check_model_word(ref_model.regs[27], 32'h08000000, "r27");
                check_model_word(ref_model.regs[28], 32'h00008000, "r28");
                check_model_word(ref_model.regs[29], 32'h00008001, "r29");
                check_model_word(ref_model.regs[30], 32'hffffffff, "r30");
                check_model_word(ref_model.regs[31], 32'h00000000, "r31");
                check_model_word(ref_model.write_count, 32, "register write count");
            end
            1: begin
                check_model_word(ref_model.regs[0], 32'h00000000, "r0");
                check_model_word(ref_model.regs[1], 32'h00000040, "r1");
                check_model_word(ref_model.regs[2], 32'h0000007b, "r2");
                check_model_word(ref_model.regs[3], 32'h0000007b, "r3");
                check_model_word(ref_model.regs[4], 32'h000000f6, "r4");
                check_model_word(ref_model.regs[5], 32'hfffffff6, "r5");
                check_model_word(ref_model.regs[6], 32'hfffffff6, "r6");
                check_model_word(ref_model.regs[7], 32'hfffffff6, "r7");
                check_model_word(ref_model.regs[8], 32'hfffffff9, "r8");
                check_model_word(ref_model.regs[9], 32'hfffffff9, "r9");
                check_model_word(ref_model.regs[10], 32'h0000007b, "r10");
                check_model_word(ref_model.regs[11], 32'h0000000b, "r11");
                check_model_word(ref_model.regs[12], 32'h00000000, "r12");
                check_model_word(ref_model.regs[13], 32'h00000007, "r13");
                check_model_word(ref_model.regs[14], 32'h00000082, "r14");
                check_model_word(ref_model.dmem[15], 32'h0000007b, "memory byte address 60");
                check_model_word(ref_model.dmem[16], 32'h0000007b, "memory byte address 64");
                check_model_word(ref_model.dmem[17], 32'h000000f6, "memory byte address 68");
                check_model_word(ref_model.dmem[18], 32'hfffffff6, "memory byte address 72");
                check_model_word(ref_model.dmem[19], 32'hfffffff6, "memory byte address 76");
                check_model_word(ref_model.dmem[20], 32'hfffffff9, "memory byte address 80");
                check_model_word(ref_model.dmem[21], 32'h00000000, "memory byte address 84");
                check_model_word(ref_model.write_count, 14, "register write count");
            end
            2: begin
                check_model_word(ref_model.regs[0], 32'h00000000, "r0");
                check_model_word(ref_model.regs[1], 32'h00000007, "r1");
                check_model_word(ref_model.regs[2], 32'h00000008, "r2");
                check_model_word(ref_model.regs[3], 32'h0000000b, "r3");
                check_model_word(ref_model.regs[4], 32'h0000000c, "r4");
                check_model_word(ref_model.regs[5], 32'h0000000d, "r5");
                check_model_word(ref_model.regs[6], 32'h0000000e, "r6");
                check_model_word(ref_model.regs[7], 32'h0000000f, "r7");
                check_model_word(ref_model.regs[8], 32'h00000000, "r8");
                check_model_word(ref_model.regs[9], 32'h00000011, "r9");
                check_model_word(ref_model.regs[10], 32'h00000000, "r10");
                check_model_word(ref_model.regs[11], 32'h00000000, "r11");
                check_model_word(ref_model.regs[12], 32'h00000000, "r12");
                check_model_word(ref_model.regs[13], 32'h00000007, "r13");
                check_model_word(ref_model.regs[14], 32'h00000000, "r14");
                check_model_word(ref_model.regs[15], 32'h00000012, "r15");
                check_model_word(ref_model.regs[16], 32'h00000000, "r16");
                check_model_word(ref_model.regs[17], 32'h00000013, "r17");
                check_model_word(ref_model.regs[18], 32'h00000000, "r18");
                check_model_word(ref_model.regs[19], 32'h00000014, "r19");
                check_model_word(ref_model.dmem[0], 32'h00000000, "memory byte address 0");
                check_model_word(ref_model.dmem[1], 32'h00000000, "memory byte address 4");
                check_model_word(ref_model.dmem[2], 32'h00000000, "memory byte address 8");
                check_model_word(ref_model.dmem[3], 32'h00000007, "memory byte address 12");
                check_model_word(ref_model.dmem[4], 32'h00000000, "memory byte address 16");
                check_model_word(ref_model.dmem[5], 32'h00000000, "memory byte address 20");
                check_model_word(ref_model.write_count, 17, "register write count");
                check_model_word(ref_model.branches_taken, 6, "taken branch count");
                check_model_word(ref_model.branches_not_taken, 3, "not-taken branch count");
                check_model_word(ref_model.jumps, 2, "accepted jump count");
            end
        endcase
        if (inject_dut_error == 1)
            uut.rf1.register[3] = uut.rf1.register[3] ^ 32'd1;
        else if (inject_dut_error == 2)
            uut.mem1.dmem[16] = uut.mem1.dmem[16] ^ 32'd1;
        sample_final_state();
        if (errors != 0 || model_errors != 0 || scoreboard_errors != 0)
            $fatal(1, "SCOREBOARD TEST FAIL: encoder=%0d model=%0d scoreboard=%0d",
                   errors, model_errors, scoreboard_errors);
        $display("SCOREBOARD TEST PASS: test=%0d checks=%0d model_checks=%0d",
                 test_id, scoreboard_checks, model_checks);
        $finish;
    end
endmodule
