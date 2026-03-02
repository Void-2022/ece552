`default_nettype none

// The arithmetic logic unit (ALU) is responsible for performing the core
// calculations of the processor. It takes two 32-bit operands and outputs
// a 32 bit result based on the selection operation - addition, comparison,
// shift, or logical operation. This ALU is a purely combinational block, so
// you should not attempt to add any registers or pipeline it.
module alu (
    // NOTE: Both 3'b010 and 3'b011 are used for set less than operations and
    // your implementation should output the same result for both codes. The
    // reason for this will become clear in project 3.
    //
    // Major operation selection.
    // 3'b000: addition/subtraction if `i_sub` asserted
    // 3'b001: shift left logical
    // 3'b010,
    // 3'b011: set less than/unsigned if `i_unsigned` asserted
    // 3'b100: exclusive or
    // 3'b101: shift right logical/arithmetic if `i_arith` asserted
    // 3'b110: or
    // 3'b111: and
    input  wire [ 2:0] i_opsel,
    // When asserted, addition operations should subtract instead.
    // This is only used for `i_opsel == 3'b000` (addition/subtraction).
    input  wire        i_sub,
    // When asserted, comparison operations should be treated as unsigned.
    // This is used for branch comparisons and set less than unsigned. For
    // b ranch operations, the ALU result is not used, only the comparison
    // results.
    input  wire        i_unsigned,
    // When asserted, right shifts should be treated as arithmetic instead of
    // logical. This is only used for `i_opsel == 3'b101` (shift right).
    input  wire        i_arith,
    // First 32-bit input operand.
    input  wire [31:0] i_op1,
    // Second 32-bit input operand.
    input  wire [31:0] i_op2,
    // 32-bit output result. Any carry out should be ignored.
    output wire [31:0] o_result,
    // Equality result. This is used externally to determine if a branch
    // should be taken.
    output wire        o_eq,
    // Set less than result. This is used externally to determine if a branch
    // should be taken.
    output wire        o_slt
);
    // TODO: Fill in your implementation here.
    wire [31:0] add_sub_result;
    wire [31:0] shift_left_result;
    wire [31:0] shift_right_result;
    wire [31:0] xor_result;
    wire [31:0] or_result;
    wire [31:0] and_result;
    wire [31:0] slt_result;

    //addition/subtraction
    assign add_sub_result = i_sub ? (i_op1 - i_op2) : (i_op1 + i_op2);

    // shift left logical (barrel shifter; variable shift operators disallowed)
    wire [4:0] shamt_left = i_op2[4:0];

    wire [31:0] sll_1  = shamt_left[0] ? {i_op1[30:0], 1'b0}   : i_op1;
    wire [31:0] sll_2  = shamt_left[1] ? {sll_1[29:0], 2'b0}   : sll_1;
    wire [31:0] sll_4  = shamt_left[2] ? {sll_2[27:0], 4'b0}   : sll_2;
    wire [31:0] sll_8  = shamt_left[3] ? {sll_4[23:0], 8'b0}   : sll_4;
    wire [31:0] sll_16 = shamt_left[4] ? {sll_8[15:0], 16'b0}  : sll_8;

    assign shift_left_result = sll_16;

    //shift right logical/arithmetic
    //somehow the signed right shift operator >>> does not work in this case, so we have to do it manually 
    //by filling the sign bit if the sign bit is 1 and the shift amount is not 0
    //assign shift_right_result = i_arith ? $signed({i_op1}) >>> i_op2[4:0] : i_op1 >> i_op2[4:0];
    // shift right logical/arithmetic (barrel shifter; variable shift operators disallowed)
    wire [4:0] shamt = i_op2[4:0];
    wire sign = i_op1[31];

    // -------------------------
    // SRL: logical right shift
    // -------------------------
    wire [31:0] srl_1  = shamt[0] ? {1'b0,  i_op1[31:1]}        : i_op1;
    wire [31:0] srl_2  = shamt[1] ? {2'b0,  srl_1[31:2]}        : srl_1;
    wire [31:0] srl_4  = shamt[2] ? {4'b0,  srl_2[31:4]}        : srl_2;
    wire [31:0] srl_8  = shamt[3] ? {8'b0,  srl_4[31:8]}        : srl_4;
    wire [31:0] srl_16 = shamt[4] ? {16'b0, srl_8[31:16]}       : srl_8;
    wire [31:0] logical = srl_16;

    // -------------------------
    // SRA: arithmetic right shift (sign-extend)
    // -------------------------
    wire [31:0] sra_1  = shamt[0] ? {i_op1[31],        i_op1[31:1]}  : i_op1;
    wire [31:0] sra_2  = shamt[1] ? {{2{i_op1[31]}},   sra_1[31:2]}  : sra_1;
    wire [31:0] sra_4  = shamt[2] ? {{4{i_op1[31]}},   sra_2[31:4]}  : sra_2;
    wire [31:0] sra_8  = shamt[3] ? {{8{i_op1[31]}},   sra_4[31:8]}  : sra_4;
    wire [31:0] sra_16 = shamt[4] ? {{16{i_op1[31]}},  sra_8[31:16]} : sra_8;
    wire [31:0] arith = sra_16;

    assign shift_right_result = i_arith ? arith : logical;
    
    //xor
    assign xor_result = i_op1 ^ i_op2;

    //or
    assign or_result = i_op1 | i_op2;

    //and
    assign and_result = i_op1 & i_op2;

    //set less than/unsigned
    assign slt_result = {31'b0, o_slt};

    //result selection
    assign o_result = (i_opsel == 3'b000) ? add_sub_result :
                      (i_opsel == 3'b001) ? shift_left_result :
                      (i_opsel == 3'b010 || i_opsel == 3'b011) ? slt_result :
                      (i_opsel == 3'b100) ? xor_result :
                      (i_opsel == 3'b101) ? shift_right_result :
                      (i_opsel == 3'b110) ? or_result :
                      (i_opsel == 3'b111) ? and_result :
                      32'b0;
    //equality result
    assign o_eq = (i_op1 == i_op2);

    //set less than result
    // set less than result (no $signed)
    wire a_neg = i_op1[31];
    wire b_neg = i_op2[31];

    wire signed_lt =
        (a_neg != b_neg) ? a_neg : (i_op1 < i_op2);   // same sign -> compare magnitude as unsigned

    assign o_slt = i_unsigned ? (i_op1 < i_op2) : signed_lt;


    // assign o_slt = i_unsigned ? (i_op1 < i_op2) :
    //                          ($signed(i_op1) < $signed(i_op2));
endmodule

`default_nettype wire
