module RegisterFile (
    input clk,
    input reset,
    input [4:0] rs1,
    input [4:0] rs2,
    input [4:0] writereg,
    input [31:0] writedata,
    input regwrite,
    output reg [31:0] readdata1,
    output reg [31:0] readdata2
);

reg [31:0] register [31:0];
integer i;

always @(posedge clk) begin
    if (!reset) begin
        for (i = 0; i < 32; i = i + 1) begin
            register[i] <= 32'd0;
        end
    end else if (regwrite && writereg != 5'd0) begin
        register[writereg] <= writedata;
    end
end

always @(*) begin
    readdata1 = (rs1 == 5'd0) ? 32'd0 :
                (regwrite && writereg == rs1 && writereg != 5'd0) ? writedata :
                register[rs1];

    readdata2 = (rs2 == 5'd0) ? 32'd0 :
                (regwrite && writereg == rs2 && writereg != 5'd0) ? writedata :
                register[rs2];
end

endmodule