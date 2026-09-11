module IMEM (
    input [31:0] readadr,
    output [31:0] inst
);

    reg [31:0] mem [0:255];

    initial begin
        $readmemh("D:/HDL/DoAn/instruction.txt", mem);
    end

    assign inst = mem[readadr[31:2]];

endmodule