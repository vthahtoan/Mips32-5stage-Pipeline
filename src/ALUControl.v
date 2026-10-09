module ALUControl (
    input [5:0] funct,
    input [2:0] aluop,
    output reg [5:0] aluctrl
);
always @(*) begin
    case (aluop)
        3'd0: aluctrl = funct;
        3'd1: aluctrl = 6'h20;
        3'd2: aluctrl = 6'h22;
        3'd3: aluctrl = 6'h24;
        3'd4: aluctrl = 6'h25;
        default: aluctrl = 6'h00;
    endcase
end
endmodule