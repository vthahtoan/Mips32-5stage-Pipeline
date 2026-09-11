`timescale 1ns / 1ps

module tb_toplevel();

    reg clk;
    reg pcreset;
    wire [31:0] writeback;
    wire [31:0] pc_out;
    wire [4:0] rd;
    wire enwrite;

    toplevel uut (
        .clk(clk),
        .pcreset(pcreset),
        .writeback(writeback),
        .pc_out(pc_out),
        .rd(rd),
        .enwrite(enwrite)
    );

    always #10 clk = ~clk;
	 initial begin
        clk = 0;
        pcreset = 0;
        
        #25;
        
        pcreset = 1;

        #3000;
        $stop;
    end

endmodule