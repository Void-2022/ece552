// this is the top module without the memories (currently dummies)
module hart #(
    // After reset, the program counter (PC) should be initialized to this
    // address and start executing instructions from there.
    parameter RESET_ADDR = 32'h00000000
) (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,

    // Instruction fetch goes through a read only instruction memory (imem)
    // port. The port accepts a 32-bit address (e.g. from the program counter)
    // per cycle and combinationally returns a 32-bit instruction word. This
    // is not representative of a realistic memory interface; it has been
    // modeled as more similar to a DFF or SRAM to simplify phase 3. In
    // later phases, you will replace this with a more realistic memory.
    //
    // 32-bit read address for the instruction memory. This is expected to be
    // 4 byte aligned - that is, the two LSBs should be zero.
    output wire [31:0] o_imem_raddr, // DRIVEN
    // Instruction word fetched from memory, available on the same cycle.
    input  wire [31:0] i_imem_rdata,
    

    // Data memory accesses go through a separate read/write data memory (dmem)
    // that is shared between read (load) and write (stored). The port accepts
    // a 32-bit address, read or write enable, and mask (explained below) each
    // cycle. Reads are combinational - values are available immediately after
    // updating the address and asserting read enable. Writes occur on (and
    // are visible at) the next clock edge.
    //
    // Read/write address for the data memory. This should be 32-bit aligned
    // (i.e. the two LSB should be zero). See `o_dmem_mask` for how to perform
    // half-word and byte accesses at unaligned addresses.
    output wire [31:0] o_dmem_addr, // DRIVE
    // When asserted, the memory will perform a read at the aligned address
    // specified by `o_dmem_addr` and return the 32-bit word at that address
    // immediately (i.e. combinationally). It is illegal to assert this and
    // `o_dmem_wen` on the same cycle.
    output wire        o_dmem_ren, // DRIVEN
    // When asserted, the memory will perform a write to the aligned address
    // `o_dmem_addr`. When asserted, the memory will write the bytes in
    // `o_dmem_wdata` (specified by the mask) to memory at the specified
    // address on the next rising clock edge. It is illegal to assert this and
    // `o_dmem_ren` on the same cycle.
    output wire        o_dmem_wen, // DRIVEN
    // The 32-bit word to write to memory when `o_dmem_wen` is asserted. When
    // write enable is asserted, the byte lanes specified by the mask will be
    // written to the memory word at the aligned address at the next rising
    // clock edge. The other byte lanes of the word will be unaffected.
    output wire [31:0] o_dmem_wdata, // DRIVEN
    // The dmem interface expects word (32 bit) aligned addresses. However,
    // WISC-25 supports byte and half-word loads and stores at unaligned and
    // 16-bit (half-byte) aligned addresses, respectively. To support this, 
    // the access mask specifies which bytes within the 32-bit word are actually 
    // read from or written to memory.
    //                         12345678 => 1000 1001 1002 1003
    //                          byte0 byte1 b2 b3
    // To perform a half-word read at address 0x00001003, align `o_dmem_addr`
    // to 0x00001000, assert `o_dmem_ren`, and set the mask to 0b1100 to
    // indicate that only the upper two bytes should be read. Only the upper
    // two bytes of `i_dmem_rdata` can be assumed to have valid data; to
    // calculate the final value of the `lh[u]` instruction, shift the rdata
    // word right by 16 bits and sign/zero extend as appropriate.
    //
    // To perform a byte write at address 0x00002003, align `o_dmem_addr` to
    // `0x00002000`, assert `o_dmem_wen`, and set the mask to 0b1000 to
    // indicate that only the upper byte should be written. On the next clock
    // cycle, the upper byte of `o_dmem_wdata` will be written to memory, with
    // the other three bytes of the aligned word unaffected. Remember to shift
    // the value of the `sb` instruction (that is, r[rs2]) left by 24 bits to 
    // place it in the appropriate byte lane.
    output wire [ 3:0] o_dmem_mask, // DRIVEN
    // The 32-bit word read from data memory. When `o_dmem_ren` is asserted,
    // this will immediately reflect the contents of memory at the specified
    // address, for the bytes enabled by the mask. When read enable is not
    // asserted, or for bytes not set in the mask, the value is undefined.
    input  wire [31:0]     i_dmem_rdata,


	// The output `retire` interface is used to signal to the testbench that
    // the CPU has completed and retired an instruction. A single cycle
    // implementation will assert this every cycle; however, a pipelined
    // implementation that needs to stall (due to internal hazards or waiting
    // on memory accesses) will not assert the signal on cycles where the
    // instruction in the writeback stage is not retiring.
    //
    // Asserted when an instruction is being retired this cycle. If this is
    // not asserted, the other retire signals are ignored and may be left invalid.
    output wire        o_retire_valid, // DRIVEN
    // The 32 bit instruction word of the instrution being retired. This
    // should be the unmodified instruction word fetched from instruction
    // memory.
    output wire [31:0] o_retire_inst, // DRIVEN
    // Asserted if the instruction produced a trap, due to an illegal
    // instruction, unaligned data memory access, or unaligned instruction
    // address on a taken branch or jump.
    output wire        o_retire_trap, // DRIVEN
    // Asserted if the instruction is an `ebreak` instruction used to halt the
    // processor. This is used for debugging and testing purposes to end
    // a program.
    output wire        o_retire_halt, // DRIVEN
    // The first register address read by the instruction being retired. If
    // the instruction does not read from a register (like `lui`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs1_raddr, // DRIVEN
    // The second register address read by the instruction being retired. If
    // the instruction does not read from a second register (like `addi`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs2_raddr, // DRIVEN
    // The first source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs1 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs1_rdata, // DRIVEN
    // The second source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs2 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs2_rdata, // DRIVEN
    // The destination register address written by the instruction being
    // retired. If the instruction does not write to a register (like `sw`),
    // this should be 5'd0.
    output wire [ 4:0] o_retire_rd_waddr, // DRIVEN
    // The destination register data written to the register file in the
    // writeback stage by this instruction. If rd is 5'd0, this field is
    // ignored and can be treated as a don't care.
    output wire [31:0] o_retire_rd_wdata,  // DRIVEN
    // The current program counter of the instruction being retired - i.e.
    // the instruction memory address that the instruction was fetched from.
    output wire [31:0] o_retire_pc,  // DRIVEN
    // the next program counter after the instruction is retired. For most
    // instructions, this is `o_retire_pc + 4`, but must be the branch or jump
    // target for *taken* branches and jumps.
    output wire [31:0] o_retire_next_pc // DRIVEN

`ifdef RISCV_FORMAL
    ,`RVFI_OUTPUTS,
`endif
);
    /// Fill in your implementation here. ///
    
    // wire and reg declarations for the internal logic of the hart
    wire [31:0] i_inst;
    wire [2:0] o_opsel;
    wire b_sel, rd_wen, o_sub, o_unsigned, o_arith, mem_wen, alu_src1, alu_src2;
    wire [5:0] o_format;
    // [0] R-type
    // [1] I-type
    // [2] S-type
    // [3] B-type
    // [4] U-type
    // [5] J-type
    wire u_format_load0;
    
    wire [1:0] sbhw_sel;
    //determine whether the store instruction is a byte, halfword, or word store
    wire [1:0] lbhw_sel;
    //determine whether the load instruction is a byte, halfword, or word load
    wire l_unsigned;
    //determine whether the load instruction is a signed or unsigned load(we sign extend or zero extend)
    wire is_jump, is_branch, is_jal, is_jalr;
    wire eq, slt;
    wire [31:0] op1, op2, alu_result;
    //pc declaration
    reg [31:0] pc; 
    wire [31:0] next_pc, pc_add_4, pc_add_imm, imm;

    //rf declaration
    //address will be from the instruction, 
    //rs1 is bits 19:15, 
    //rs2 is bits 24:20, 
    //and rd is bits 11:7
    wire [31:0] rs1_rdata, rs2_rdata, rd_wdata;

    // from control, enables read from dmem
    wire is_load;

    // for store/load width logic
    wire [3:0] load_mask;
    wire [3:0] store_mask;
    wire [3:0] dmem_mask_raw;
    wire [31:0] store_wdata_shifted;

    wire [31:0] load_shifted_data;
    wire [31:0] load_result_data; // previous name: mem_data; this is what to load to reg

    // retire/control helper signals
    wire rd_wen_safe;
    wire [31:0] jalr_target;


    /////////////////////////////////////////////////////////////////////////////////////////
    /// INSTANTIATIONS  ////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////

    //instantiate the control unit
    control iControl (
        .i_inst(i_inst),
        .o_rd_wen(rd_wen),
        .o_opsel(o_opsel),
        .o_sub(o_sub),
        .o_unsigned(o_unsigned),
        .o_arith(o_arith),
        .o_mem_wen(mem_wen),
        .o_alu_src_2(alu_src2),
        .o_format(o_format),
        .o_is_lui(u_format_load0),
        .o_alu_src_1(alu_src1),
        .sbhw_sel(sbhw_sel),
        .lbhw_sel(lbhw_sel),
        .l_unsigned(l_unsigned),
        .o_is_jump(is_jump),
        .is_branch(is_branch),
        .is_jal(is_jal),
        .is_jalr(is_jalr),
        .o_is_load(is_load)
    );

    //instantiate the branch decoder
    branch_decoder iBD (
        .funct3(i_inst[14:12]),
        .is_branch(is_branch),
        .eq(eq),
        .slt(slt),
        .b_sel(b_sel)
    );

    //instantiate the alu
    alu iALU (
        .i_op1(op1),
        .i_op2(op2),
        .i_opsel(o_opsel),
        .i_sub(o_sub),
        .i_unsigned(o_unsigned),
        .i_arith(o_arith),
        .o_result(alu_result),
        .o_eq(eq),
        .o_slt(slt)
    );

    assign op1 = alu_src1 ? (u_format_load0 ? 32'd0 : pc) : rs1_rdata;
    assign op2 = alu_src2 ? rs2_rdata : imm;

    //instantiate the immediate generator
    imm iImm (
        .i_inst(i_inst),
        .i_format(o_format),
        .o_immediate(imm)
    );

    //instantiate the register file
    //enable is low for single cycle processor
    rf #(.BYPASS_EN(0)) iRF (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_rs1_raddr(i_inst[19:15]),
        .o_rs1_rdata(rs1_rdata),
        .i_rs2_raddr(i_inst[24:20]),
        .o_rs2_rdata(rs2_rdata),
        .i_rd_wen(rd_wen_safe),
        .i_rd_waddr(i_inst[11:7]),
        .i_rd_wdata(rd_wdata)
    );

    // for RF's retires; not sure if needed
    assign rd_wen_safe = rd_wen && !o_retire_halt && !o_retire_trap;
    assign rd_wdata = is_load ? load_result_data :
                      (is_jump) ? pc_add_4 : // for jal and jalr, we write the return address (pc + 4) to rd
                      alu_result; // for other instructions, we write the result of the ALU calculation to rd

    /// "instantiate" the PC ///
    always @(posedge i_clk) begin
        if (i_rst) begin
            pc <= RESET_ADDR;
        end else begin
            pc <= next_pc;
        end
    end


    /////////////////////////////////////////////////////////////////////////////////////////
    ////// LOGIC ///////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////


    //////////////////////////
    /// INSTRUCTION FETCH ///
    ////////////////////////
    assign o_imem_raddr = pc; // the address to fetch the instruction from, which is the current pc
    assign i_inst = i_imem_rdata; // instruction fetched from imem
    assign o_retire_inst = i_inst; // the instruction being retired is the instruction fetched from imem




    /////////////////////////////
    /// DATA MEMORY ACCESSES ///
    ///////////////////////////
    assign o_dmem_addr = {alu_result[31:2], 2'b00}; // dmem takes in aligned addresses
    assign o_dmem_ren = is_load && !o_retire_trap;
    assign o_dmem_wen = mem_wen && !o_retire_trap;



    /////////////////////////////////////
    /// DATA MEMORY ACCESSES - STORE ///
    ///////////////////////////////////

    // mask for load/store byte lanes - check long wall of text (line 53-72)
    // note unalligned data memory accesses are not handled here, but in trap logic
    assign load_mask = (lbhw_sel == 2'b00) ? ((alu_result[1:0] == 2'b00) ? 4'b0001 :
                                              (alu_result[1:0] == 2'b01) ? 4'b0010 :
                                              (alu_result[1:0] == 2'b10) ? 4'b0100 :
                                                                          4'b1000) :
                       (lbhw_sel == 2'b01) ? (alu_result[1] ? 4'b1100 : 4'b0011) :
                       (lbhw_sel == 2'b10) ? 4'b1111 :
                                              4'b0000;

    assign store_mask = (sbhw_sel == 2'b00) ? ((alu_result[1:0] == 2'b00) ? 4'b0001 :
                                               (alu_result[1:0] == 2'b01) ? 4'b0010 :
                                               (alu_result[1:0] == 2'b10) ? 4'b0100 :
                                                                           4'b1000) :
                        (sbhw_sel == 2'b01) ? (alu_result[1] ? 4'b1100 : 4'b0011) :
                        (sbhw_sel == 2'b10) ? 4'b1111 :
                                               4'b0000;

    assign dmem_mask_raw = is_load ? load_mask :
                           mem_wen ? store_mask :
                           4'b0000;

    assign o_dmem_mask = o_retire_trap ? 4'b0000 : dmem_mask_raw; // unsure if needed

    // shift rs2 into the selected byte lanes for store's writes
    assign store_wdata_shifted = (alu_result[1:0] == 2'b00) ? rs2_rdata :
                                 (alu_result[1:0] == 2'b01) ? {rs2_rdata[23:0], 8'b0} :
                                 (alu_result[1:0] == 2'b10) ? {rs2_rdata[15:0], 16'b0} :
                                                               {rs2_rdata[7:0], 24'b0};
    assign o_dmem_wdata = store_wdata_shifted;



    ////////////////////////////////////
    /// DATA MEMORY ACCESSES - LOAD ///
    //////////////////////////////////

    // align selected byte lane to bits [7:0] before extension 
    // ("only x bytes can be assumed to have valid data")
    assign load_shifted_data = (alu_result[1:0] == 2'b00) ? i_dmem_rdata :
                               (alu_result[1:0] == 2'b01) ? {8'b0,  i_dmem_rdata[31:8]} :
                               (alu_result[1:0] == 2'b10) ? {16'b0, i_dmem_rdata[31:16]} :
                                                             {24'b0, i_dmem_rdata[31:24]};

    // load data selection and sign/zero extension
    // ("shift the rdata word right by x bits and sign/zero extend as appropriate")
    assign load_result_data = (lbhw_sel == 2'b00) ? // lb/lbu
                        (l_unsigned ? {24'b0, load_shifted_data[7:0]} :
                                      {{24{load_shifted_data[7]}}, load_shifted_data[7:0]}) :

                        (lbhw_sel == 2'b01) ? // lh/lhu
                            (l_unsigned ? {16'b0, load_shifted_data[15:0]} :
                            {{16{load_shifted_data[15]}}, load_shifted_data[15:0]}) :

                      (lbhw_sel == 2'b10) ? // lw
                        load_shifted_data :
                        32'b0;



    ///////////////////////
    //// RETIRE LOGIC ////
    /////////////////////

    // ebreak op code is 1 1 1 0 0 1 1 and other bits are 0
    assign o_retire_halt = (i_inst[31:0]==32'h00100073) ? 1'b1 : 1'b0;

    /// retired valid is asserted for evey cycle, for single cycle implementation ///
    assign o_retire_valid = 1'b1;


    ////////////////////////////
    /// RETIRE LOGIC - TRAP ///
    //////////////////////////

    // trap is supposed to be asserted for the following:
    // 1. illegal instructions: i.e., not of supported format, with the exception of halt
    // 2. unaligned data memory access:
    //      2a. accessing addresses (alu_result[1:0]) ended with 01/11 for a lh/sh
    //      2b. accessing addresses not ended with 00 for a lw/sw
    //      loading/storing a single byte is always fine
    // 3. unaligned instruction address on a taken branch or jump
    
    // useful signals
    wire illegal_inst;
    wire legal_inst;
    wire misaligned_load, misaligned_store;
    wire taken_control_flow;
    wire misaligned_next_pc;

    assign illegal_inst = ((o_format == 6'b000000) && !(o_retire_halt));

    assign misaligned_load = is_load && (
                                (lbhw_sel == 2'b01 && alu_result[0]) ||
                                (lbhw_sel == 2'b10 && (alu_result[1:0] != 2'b00)) ||
                                (lbhw_sel == 2'b11)
                             );

    assign misaligned_store = mem_wen && (
                                 (sbhw_sel == 2'b01 && alu_result[0]) ||
                                 (sbhw_sel == 2'b10 && (alu_result[1:0] != 2'b00)) ||
                                 (sbhw_sel == 2'b11)
                              );

    assign taken_control_flow = b_sel || is_jal || is_jalr;

    assign misaligned_next_pc = taken_control_flow && (next_pc[1:0] != 2'b00);

    assign o_retire_trap = illegal_inst || misaligned_load || misaligned_store || misaligned_next_pc;
    

    //////////////////////////
    /// RETIRE LOGIC - RF ///
    ////////////////////////

    // per Piazza (question @78), we should not let through instruction
    // fields only if they are used, contrary to the comments
    assign o_retire_rs1_raddr = i_inst[19:15];
    assign o_retire_rs1_rdata = rs1_rdata;
    assign o_retire_rs2_raddr = i_inst[24:20];
    assign o_retire_rs2_rdata = rs2_rdata;

    // if the write enable is high and the write address matches the read address
    // we can bypass the write data to the read data for the retire interface
    assign o_retire_rd_waddr = rd_wen_safe ? i_inst[11:7] : 5'd0;
    assign o_retire_rd_wdata = rd_wdata;


    //////////////////////////
    /// RETIRE LOGIC - PC ///
    ////////////////////////

    assign jalr_target = {alu_result[31:1], 1'b0};
    assign pc_add_4 = pc + 4;
    assign pc_add_imm = pc + imm; // the target address calculated by the branch/jump logic
    assign next_pc = is_jalr ? jalr_target : (b_sel||is_jal ? pc_add_imm : pc_add_4);

    //assign the retired pc to the current pc
    assign o_retire_pc = pc;
    assign o_retire_next_pc = next_pc;




endmodule

`default_nettype wire
