module IF_ID_reg (
    input clk,
    input pcreset,
    input ex_flush,
    input jump,
    input if_id_write,
    input [31:0] inst_in,
    input [31:0] pc_4_in,
    output reg [31:0] if_id_inst,
    output reg [31:0] if_id_pc
);

always @(posedge clk or negedge pcreset) begin
    if(!pcreset) begin
        if_id_inst <= 32'd0;
        if_id_pc   <= 32'd0;
    end else if (ex_flush || jump) begin
        if_id_inst <= 32'd0;
        if_id_pc   <= 32'd0;
    end else if (if_id_write) begin
        if_id_inst <= inst_in;
        if_id_pc   <= pc_4_in;
    end
end

endmodule