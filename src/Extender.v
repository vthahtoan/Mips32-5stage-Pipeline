module Extender (
    input [15:0] a,
    input is_sign_ext,
    output [31:0] b
);
    assign b = (is_sign_ext) ? {{16{a[15]}}, a} : {16'd0, a};
endmodule