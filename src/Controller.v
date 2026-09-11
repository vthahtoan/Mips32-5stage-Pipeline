module Controller (
    input [5:0] inst,
    output reg regdst,
    output reg branch,
    output reg bne,
    output reg memread,
    output reg memtoreg,
    output reg [2:0] aluop,
    output reg memwrite,
    output reg alusrc,
    output reg regwrite,
    output reg jump,
    output reg is_sign_ext
);

always @(*) begin
    case (inst)
        // R-Type (add, sub, and, or, nor, xor, slt, mfhi, mflo, mult, div)
        6'h00: begin
            regdst = 1;
            branch = 0;
            memread = 0;
            memtoreg = 0;
            aluop = 3'd0;
            memwrite = 0;
            alusrc = 0;
            regwrite = 1;
            jump = 0;
            bne = 0;
            is_sign_ext = 0;
        end
        // lw
        6'h23: begin
            regdst = 0;
            branch = 0;
            memread = 1;
            memtoreg = 1;
            aluop = 3'd1;
            memwrite = 0;
            alusrc = 1;
            regwrite = 1;
            jump = 0;
            bne = 0;
            is_sign_ext = 1;
        end
        // sw
        6'h2B: begin
            regdst = 0;
            branch = 0;
            memread = 0;
            memtoreg = 0;
            aluop = 3'd1;
            memwrite = 1;
            alusrc = 1;
            regwrite = 0;
            jump = 0;
            bne = 0;
            is_sign_ext = 1;
        end
        // beq
        6'h04: begin
            regdst = 0;
            branch = 1;
            memread = 0;
            memtoreg = 0;
            aluop = 3'd2;
            memwrite = 0;
            alusrc = 0;
            regwrite = 0;
            jump = 0;
            bne = 0;
            is_sign_ext = 1;
        end
        // bne
        6'h05: begin
            regdst = 0;
            branch = 0;
            memread = 0;
            memtoreg = 0;
            aluop = 3'd2;
            memwrite = 0;
            alusrc = 0;
            regwrite = 0;
            jump = 0;
            bne = 1;
            is_sign_ext = 1;
        end
        // addi
        6'h08: begin
            regdst = 0;
            branch = 0;
            memread = 0;
            memtoreg = 0;
            aluop = 3'd1;
            memwrite = 0;
            alusrc = 1;
            regwrite = 1;
            jump = 0;
            bne = 0;
            is_sign_ext = 1;
        end
        // li / addiu
        6'h09: begin
            regdst = 0;
            branch = 0;
            memread = 0;
            memtoreg = 0;
            aluop = 3'd1;
            memwrite = 0;
            alusrc = 1;
            regwrite = 1;
            jump = 0;
            bne = 0;
            is_sign_ext = 1;
        end
        // andi
        6'h0C: begin
            regdst = 0;
            branch = 0;
            memread = 0;
            memtoreg = 0;
            aluop = 3'd3;
            memwrite = 0;
            alusrc = 1;
            regwrite = 1;
            jump = 0;
            bne = 0;
            is_sign_ext = 0;
        end
        // ori
        6'h0D: begin
            regdst = 0;
            branch = 0;
            memread = 0;
            memtoreg = 0;
            aluop = 3'd4;
            memwrite = 0;
            alusrc = 1;
            regwrite = 1;
            jump = 0;
            bne = 0;
            is_sign_ext = 0;
        end
        // jump
        6'h02: begin
            regdst = 0;
            branch = 0;
            memread = 0;
            memtoreg = 0;
            aluop = 3'd0;
            memwrite = 0;
            alusrc = 0;
            regwrite = 0;
            jump = 1;
            bne = 0;
            is_sign_ext = 0;
        end
        default: begin
            regdst = 0;
            branch = 0;
            memread = 0;
            memtoreg = 0;
            aluop = 3'd0;
            memwrite = 0;
            alusrc = 0;
            regwrite = 0;
            jump = 0;
            bne = 0;
            is_sign_ext = 0;
        end
    endcase
end

endmodule