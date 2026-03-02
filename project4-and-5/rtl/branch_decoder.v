module branch_decoder (
    input  wire [2:0] funct3,
    input  wire is_branch,
    input wire eq,
    input wire slt,
    output wire b_sel
);
    //TODO
    assign b_sel = (is_branch && ((funct3 == 3'b000 && eq) || // beq
                              (funct3 == 3'b001 && !eq) || // bne
                              (funct3 == 3'b100 && slt) || // blt
                              (funct3 == 3'b101 && !slt) || // bge
                              (funct3 == 3'b110 && slt) || // bltu
                              (funct3 == 3'b111 && !slt))); // bgeu

endmodule