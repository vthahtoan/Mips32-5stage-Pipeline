module PC (
    input clk,
    input pcreset,
    input pcwrite,
    input [31:0] pc_next,
    output reg [31:0] pc
);

always @(posedge clk or negedge pcreset) begin
    if (!pcreset)
        pc <= 32'd0;
    else if (pcwrite)
        pc <= pc_next;
end

endmodule