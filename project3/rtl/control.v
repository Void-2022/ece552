module control(
    input  wire [31:0] i_inst,
    output wire o_rd_wen,
    output reg [2:0] o_opsel,
    output reg o_sub,
    output reg o_unsigned,
    output reg o_arith,
    output wire o_mem_wen,
    output wire o_alu_src_2,
    output wire o_alu_src_1,
    output reg [5:0] o_format, // one-hot format code
    // [0] R-type
    // [1] I-type
    // [2] S-type
    // [3] B-type
    // [4] U-type
    // [5] J-type
    output wire o_is_lui,

    output wire [1:0] sbhw_sel,
    //determine whether the store instruction is a byte, halfword, or word store
    output wire [1:0] lbhw_sel,
    //determine whether the load instruction is a byte, halfword, or word load
    output wire l_unsigned,
    //determine whether the load instruction is a signed or unsigned load(we sign extend or zero extend)
    output wire o_is_jump,
    output wire is_branch,
    output wire is_jal,
    output wire is_jalr,
    output wire o_is_load // this serves as both MemRead and MemtoReg
);
    //format logic 
    //R-format opcode 011 0011
    //I-format opcode 001 0011 or Load: 000 0011 or jalr: 110 0111
    //S-format opcode 010 0011
    //B-format opcode 110 0011
    //U-format opcode 011 0111 or 001 0111
    //J-format opcode 110 1111
    always @(*) begin
        case (i_inst[6:0])
            7'b0110011: o_format = 6'b000001; // R-type
            7'b0010011, 7'b0000011, 7'b1100111: o_format = 6'b000010; // I-type
            7'b0100011: o_format = 6'b000100; // S-type
            7'b1100011: o_format = 6'b001000; // B-type
            7'b0110111, 7'b0010111: o_format = 6'b010000; // U-type
            7'b1101111: o_format = 6'b100000; // J-type
            default: o_format = 6'b000000; // default case that should never happen
        endcase
    end

    

    //reg write enable logic
    //all instructions write to a register, except for B and S instructions
    assign o_rd_wen = !(o_format[2] || o_format[3]);

    //mem write enable logic
    //only S instructions write to memory
    assign o_mem_wen = o_format[2];

    // selects to store a byte, half a word, or a word
    assign sbhw_sel = i_inst[13:12];

    // selects to load a byte, half a word, or a word (needs help with masking)
    assign lbhw_sel = i_inst[13:12];

    // selects whether to load unsigned
    assign l_unsigned = i_inst[14];

    //we load 0 to sr1 when o_format is U and opcode[5] is 1
    assign o_is_lui = o_format[4] && i_inst[5];

    //is_jal logic: jal increments pc by an offset
    //when it's a j-tpye instruction (the only j-type instruction is jal), we set is_jal to 1
    assign is_jal = o_format[5];

    //is_jalr logic: jalr sets pc to be an ALU result
    assign is_jalr = i_inst[6:0] == 7'b1100111;

    assign o_is_jump = is_jal || is_jalr;

    // ALU controls: can check the RV32I Reference Card to verify the logic
    // 
    // we need to drive the following ALU inputs:
    // 1. the control inputs i_opsel, i_sub, i_unsigned, i_arith with the 
    // controls bearing the same names (ex. o_opsel for i_opsel)
    //
    // 2. the operand inputs i_op1 and i_op2 indirectly with MUX controls
    // o_alu_src1, o_alu_src2 and o_is_lui
    //
    // important fields: i_inst[14:12] = funct3, i_inst[30] = 2nd MSB of funct7
    
    /// 1. control inputs to ALU ///
    always @(*) begin
        case (i_inst[6:0])
            // register arithmetic (R)
            7'b0110011: begin
                o_opsel = i_inst[14:12];
                o_sub = i_inst[30];
                o_arith = i_inst[30];
                o_unsigned = i_inst[12];
            end
            // immediate arithmetic (I)
            7'b0010011: begin               
                    o_opsel = i_inst[14:12];
                    o_sub = 1'b0;
                    o_arith = i_inst[30];
                    o_unsigned = i_inst[12];
            end
            // conditonal branch (B)
            7'b1100011: begin
                o_opsel = (!i_inst[14] & !i_inst[13]) ? 3'b000 : 3'b011;
                o_sub = 1'b1; // for the first two that subtract
                o_arith = 1'bx;
                o_unsigned = i_inst[13];
            end
            // all other instructions add (U-type immediate arithmetic, load (I), etc.)
            default: begin
                o_opsel = 3'b000;
                o_sub = 1'b0;
                o_arith = 1'bx;
                o_unsigned = 1'bx;
            end
        endcase
    end


    /// 2. controls that help drive op1 and op2 to ALU //
    // 1 = using either PC (auipc) or 0 (lui) as src1 of the ALU
    // 0 = using rs1 as src1
    // all insturctions use/tolerate rs1 as src1, except for Us
    assign o_alu_src_1 = o_format[4];

    // 1 = using rs2 as src2
    // 0 = using imm as src2
    // all instructions use/tolerate imm as src2, except for Rs and Bs
    assign o_alu_src_2 = (o_format[0] || o_format[3]);

    assign is_branch = o_format[3];
    assign o_is_load = (i_inst[6:0] == 7'b0000011); // serves as both MemRead and MemtoReg
endmodule
