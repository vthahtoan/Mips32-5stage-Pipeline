module ALUControl (
    input [5:0] funct,
    input [2:0] aluop,
    output reg [5:0] aluctrl
);

always @(*) begin
    case (aluop)
        3'd0: aluctrl = funct;    // (R-Type)
        3'd1: aluctrl = 6'h20;    // Cộng có dấu (lw, sw, addi, li)
        3'd2: aluctrl = 6'h22;    // Trừ có dấu (beq, bne, subi)
        3'd3: aluctrl = 6'h24;    // Logic AND (andi)
        3'd4: aluctrl = 6'h25;    // Logic OR (ori)
        default: aluctrl = 6'h00; // (jump)
    endcase
end

endmodule