module DMEM (
    input clk,
    input [31:0] address,
    input [31:0] writedata,
    input memwrite,
    input memread,
    output [31:0] readdata
);
    reg [31:0] dmem [0:255];

    assign readdata = (memread) ? dmem[address[31:2]] : 32'd0;

    always @(posedge clk) begin
        if (memwrite) begin
            dmem[address[31:2]] <= writedata;
        end
    end
endmodule