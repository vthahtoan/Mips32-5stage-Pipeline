module ALU (
    input  [31:0] a,
    input  [31:0] b,
    input  [4:0]  shamt,
    input  [5:0]  aluctrl,
    output reg [31:0] result,
    output        isz
);

    always @(*) begin
        case (aluctrl)
            6'h00: result = b << shamt;
            6'h02: result = b >> shamt;
            6'h20: result = $signed(a) + $signed(b);
            6'h21: result = $unsigned(a) + $unsigned(b);
            6'h22: result = $signed(a) - $signed(b);
            6'h23: result = $unsigned(a) - $unsigned(b);
            6'h24: result = a & b;
            6'h25: result = a | b;
            6'h26: result = a ^ b;
            6'h27: result = ~(a | b);
            6'h2a: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            default: result = 32'd0;
        endcase
    end

    assign isz = (result == 32'd0) ? 1'b1 : 1'b0;
	
endmodule