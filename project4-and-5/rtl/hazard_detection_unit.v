module hazard_detection_unit (
    input  wire        i_if_id_valid,
    input  wire [31:0] i_if_id_inst,

    input  wire        i_id_ex_valid,
    input  wire        i_id_ex_rd_wen,
    input  wire [4:0]  i_id_ex_rd_waddr,
    input  wire        i_id_ex_is_branch,
    input  wire        i_id_ex_is_jal,
    input  wire        i_id_ex_is_jalr,
    input  wire        i_ex_taken_control,

    input  wire        i_ex_mem_valid,
    input  wire        i_ex_mem_rd_wen,
    input  wire [4:0]  i_ex_mem_rd_waddr,

    output wire        o_pc_en,
    output wire        o_if_id_en,
    output wire        o_if_id_flush,
    output wire        o_id_ex_flush
);

    // Refer to RV32I Reference Card
    localparam [6:0] OPCODE_OP_R   = 7'b0110011; // "register arithmetic"
    localparam [6:0] OPCODE_OP_IMM = 7'b0010011; // "immediate arithmetic"
    localparam [6:0] OPCODE_LOAD   = 7'b0000011;
    localparam [6:0] OPCODE_STORE  = 7'b0100011;
    localparam [6:0] OPCODE_BRANCH = 7'b1100011;
    localparam [6:0] OPCODE_JALR   = 7'b1100111;
    localparam [6:0] OPCODE_JAL    = 7'b1101111;

    wire [6:0] if_id_opcode;
    wire [4:0] if_id_rs1_raddr;
    wire [4:0] if_id_rs2_raddr;

    wire if_id_uses_rs1;
    wire if_id_uses_rs2;
    wire if_id_is_branch;
    wire if_id_is_jal;
    wire if_id_is_jalr;

    // That the instruction in decode reads a register written by an older
    // instruction currently in EX or MEM
    wire raw_hazard_ex;
    wire raw_hazard_mem;
    wire raw_hazard;

    // That the instruction in ID or EX affects control flow
    wire control_hazard_id;
    wire control_hazard_ex;

    assign if_id_opcode = i_if_id_inst[6:0];
    assign if_id_rs1_raddr = i_if_id_inst[19:15];
    assign if_id_rs2_raddr = i_if_id_inst[24:20];

    assign if_id_uses_rs1 =
        (if_id_opcode == OPCODE_LOAD)   ||
        (if_id_opcode == OPCODE_OP_IMM) ||
        (if_id_opcode == OPCODE_STORE)  ||
        (if_id_opcode == OPCODE_OP_R)   ||
        (if_id_opcode == OPCODE_BRANCH) ||
        (if_id_opcode == OPCODE_JALR);

    assign if_id_uses_rs2 =
        (if_id_opcode == OPCODE_STORE)  ||
        (if_id_opcode == OPCODE_OP_R)   ||
        (if_id_opcode == OPCODE_BRANCH);

    assign if_id_is_branch = (if_id_opcode == OPCODE_BRANCH);
    assign if_id_is_jal = (if_id_opcode == OPCODE_JAL);
    assign if_id_is_jalr = (if_id_opcode == OPCODE_JALR);

    // RAW hazard against the EX stage
    assign raw_hazard_ex =
        i_if_id_valid &&
        i_id_ex_valid &&
        i_id_ex_rd_wen &&
        (i_id_ex_rd_waddr != 5'd0) &&
        (
            (if_id_uses_rs1 && (i_id_ex_rd_waddr == if_id_rs1_raddr)) ||
            (if_id_uses_rs2 && (i_id_ex_rd_waddr == if_id_rs2_raddr))
        );

    // RAW hazard against the MEM stage
    assign raw_hazard_mem =
        i_if_id_valid &&
        i_ex_mem_valid &&
        i_ex_mem_rd_wen &&
        (i_ex_mem_rd_waddr != 5'd0) &&
        (
            (if_id_uses_rs1 && (i_ex_mem_rd_waddr == if_id_rs1_raddr)) ||
            (if_id_uses_rs2 && (i_ex_mem_rd_waddr == if_id_rs2_raddr))
        );

    assign raw_hazard = raw_hazard_mem || raw_hazard_ex;

    // control hazard when the B/J is still waiting in decode
    assign control_hazard_id =
        i_if_id_valid &&
        (
            if_id_is_branch ||
            if_id_is_jal ||
            if_id_is_jalr
        );

    // if EX actually redirects, keep IF/ID bubbled for that cycle too
    // otherwise, the instruction to be piped into it is already correct,
    // so no need to bubble and waste a cycle.
    assign control_hazard_ex =
        i_id_ex_valid &&
        i_ex_taken_control &&
        (
            i_id_ex_is_branch ||
            i_id_ex_is_jal ||
            i_id_ex_is_jalr
        );

    // RAW hazards take priority over control hazards because the instruction in
    // decode must stay in place until its operands are available. Only then do we
    // worry about control hazards
    assign o_if_id_en = raw_hazard ? 1'b0 : 1'b1;

    assign o_id_ex_flush = raw_hazard ? 1'b1 : 1'b0;

    assign o_if_id_flush = raw_hazard ? 1'b0 :
                           (control_hazard_id || control_hazard_ex) ? 1'b1 :
                           1'b0;

    assign o_pc_en = 
            raw_hazard ? 1'b0 :
            control_hazard_id ? 1'b0 :
            1'b1;

endmodule
