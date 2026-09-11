module HazardDetection (
    input id_ex_memread,
    input [4:0] id_ex_rd,
    input [4:0] if_id_rs1,
    input [4:0] if_id_rs2,
    output reg pcwrite,
    output reg if_id_write,
    output reg control_mux
);

always @(*) begin
    if (id_ex_memread && (id_ex_rd != 5'd0) && 
       ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2))) begin
        
        pcwrite = 0;
        if_id_write = 0;
        control_mux = 0;
        
    end else begin
        
        pcwrite = 1;
        if_id_write = 1;
        control_mux = 1;
        
    end
end

endmodule