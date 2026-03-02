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
    output wire [31:0] o_imem_raddr,
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
    output wire [31:0] o_dmem_addr,
    // When asserted, the memory will perform a read at the aligned address
    // specified by `o_dmem_addr` and return the 32-bit word at that address
    // immediately (i.e. combinationally). It is illegal to assert this and
    // `o_dmem_wen` on the same cycle.
    output wire        o_dmem_ren,
    // When asserted, the memory will perform a write to the aligned address
    // `o_dmem_addr`. When asserted, the memory will write the bytes in
    // `o_dmem_wdata` (specified by the mask) to memory at the specified
    // address on the next rising clock edge. It is illegal to assert this and
    // `o_dmem_ren` on the same cycle.
    output wire        o_dmem_wen,
    // The 32-bit word to write to memory when `o_dmem_wen` is asserted. When
    // write enable is asserted, the byte lanes specified by the mask will be
    // written to the memory word at the aligned address at the next rising
    // clock edge. The other byte lanes of the word will be unaffected.
    output wire [31:0] o_dmem_wdata,
    // The dmem interface expects word (32 bit) aligned addresses. However,
    // WISC-25 supports byte and half-word loads and stores at unaligned and
    // 16-bit (half-byte) aligned addresses, respectively. To support this, 
    // the access mask specifies which bytes within the 32-bit word are actually 
    // read from or written to memory.
    //
    // To perform a half-word read at address 0x00001002, align `o_dmem_addr`
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
    output wire [ 3:0] o_dmem_mask,
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
    output wire        o_retire_valid,
    // The 32 bit instruction word of the instrution being retired. This
    // should be the unmodified instruction word fetched from instruction
    // memory.
    output wire [31:0] o_retire_inst,
    // Asserted if the instruction produced a trap, due to an illegal
    // instruction, unaligned data memory access, or unaligned instruction
    // address on a taken branch or jump.
    output wire        o_retire_trap,
    // Asserted if the instruction is an `ebreak` instruction used to halt the
    // processor. This is used for debugging and testing purposes to end
    // a program.
    output wire        o_retire_halt,
    // The first register address read by the instruction being retired. If
    // the instruction does not read from a register (like `lui`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs1_raddr,
    // The second register address read by the instruction being retired. If
    // the instruction does not read from a second register (like `addi`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs2_raddr,
    // The first source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs1 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs1_rdata,
    // The second source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs2 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs2_rdata,
    // The destination register address written by the instruction being
    // retired. If the instruction does not write to a register (like `sw`),
    // this should be 5'd0.
    output wire [ 4:0] o_retire_rd_waddr,
    // The destination register data written to the register file in the
    // writeback stage by this instruction. If rd is 5'd0, this field is
    // ignored and can be treated as a don't care.
    output wire [31:0] o_retire_rd_wdata,
    // The current program counter of the instruction being retired - i.e.
    // the instruction memory address that the instruction was fetched from.
    output wire [31:0] o_retire_pc,
    // the next program counter after the instruction is retired. For most
    // instructions, this is `o_retire_pc + 4`, but must be the branch or jump
    // target for *taken* branches and jumps.
    output wire [31:0] o_retire_next_pc

`ifdef RISCV_FORMAL
    ,`RVFI_OUTPUTS,
`endif
);
    /// Fill in your implementation here. ///
    
    // retired valid is asserted for evey cycle, for single cycle implementation
    assign o_retire_valid = 1'b1;
    // retired instruction is just the instruction fetched from imem
    assign o_retire_inst = i_imem_rdata;
    
    // wire and reg declarations for the internal logic of the hart
    wire [31:0] i_inst;
    wire [2:0] o_opsel;
    wire b_sel, rd_wen, o_sub, o_unsigned, o_arith, o_mem_wen, o_men_to_reg, alu_src1, alu_src2;
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

    // dmem data out of load selector, ready to be loaded
    wire [31:0] to_load;
    

    wire [31:0] masked_men_data;
    wire [31:0] mask_32;
    wire [31:0] men_data;
    wire [4:0] mask_shift;
    //instantiate the control unit
    control iControl (
        .i_inst(i_inst),
        .o_rd_wen(rd_wen),
        .o_opsel(o_opsel),
        .o_sub(o_sub),
        .o_unsigned(o_unsigned),
        .o_arith(o_arith),
        .o_mem_wen(o_mem_wen),
        .o_men_to_reg(o_men_to_reg),
        .o_alu_src_2(alu_src2),
        .o_format(o_format),
        .o_is_lui(u_format_load0),
        .o_alu_src_1(alu_src1),
        .sbhw_sel(sbhw_sel),
        .lbhw_sel(lbhw_sel),
        .l_unsigned(l_unsigned),
        .is_jump(is_jump),
        .is_branch(is_branch),
        .is_jal(is_jal),
        .is_jalr(is_jalr),
        .is_load(is_load)
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
        .i_unsigned(1'b0), // for now we can just set this to 0, since we only need signed comparisons for branches
        .i_arith(o_arith),
        .o_result(alu_result),
        .o_eq(eq),
        .o_slt(slt)
    );

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
        .i_rd_wen(rd_wen),
        .i_rd_waddr(i_inst[11:7]),
        .i_rd_wdata(rd_wdata)
    );
    assign o_retire_rs1_raddr = i_inst[19:15];
    assign o_retire_rs1_rdata = rs1_rdata;
    assign o_retire_rs2_raddr = i_inst[24:20];
    assign o_retire_rs2_rdata = rs2_rdata;
    assign o_retire_rd_waddr = i_inst[11:7];
    assign o_retire_rd_wdata = rd_wdata;

    //pc logic 
    always @(posedge i_clk) begin
        if (i_rst) begin
            pc <= RESET_ADDR;
        end else begin
            pc <= next_pc;
        end
    end
    assign pc_add_4 = pc + 4;
    assign pc_add_imm = pc + imm; // the target address calculated by the branch/jump logic
    assign next_pc = is_jalr ? alu_result : (b_sel||is_jal ? pc_add_imm : pc_add_4); 
    

    //assign the retired pc to the current pc
    assign o_retire_pc = pc;
    assign o_retire_next_pc = next_pc;

    //instruction fetch
    assign o_imem_raddr = pc; // the address to fetch the instruction from, which is the current pc
    assign i_inst = i_imem_rdata; // instruction fetched from imem
    assign o_retire_inst = i_inst; // the instruction being retired is the instruction fetched from imem
    
    //alu operand selection
    //TODO
    assign op1 = alu_src1 ? (u_format_load0 ? pc : 0) : rs1_rdata;
    assign op2 = alu_src2 ? rs2_rdata : imm;

    //store selector logic
    // assign o_dmem_wdata =  (sbhw_sel[1]) ? rs2_rdata :
    //                 (sbhw_sel[0]) ? rs2_rdata[15:0] :
    //                 rs2_rdata[7:0];



    
    //memory access logic

    // Align read address if perform a load instruction
    assign o_dmem_ren = is_load;
    assign o_dmem_wen = o_mem_wen;
    assign o_dmem_addr = {alu_result[31:2], 2'b00};

    // Mask logic
    assign o_dmem_mask = (lbhw_sel == 2'b00) ? (4'b0001) : // byte access
                         (lbhw_sel == 2'b01) ? (4'b0011) : // half-word access
                         (lbhw_sel == 2'b10) ? (4'b1111) : // word access
                         4'b0000; // default case that should never happen
    
    // Extend mask to align with the correct byte lanes for unaligned accesses
    wire [31:0] o_dmem_mask_extend = {8{o_dmem_mask[3]}, 8{o_dmem_mask[2]},
                                      8{o_dmem_mask[1]}, 8{o_dmem_mask[0]}};



    /// load selector logic ///
    // Bit indicating the value of the sign bit (if load is unsigned, this will be 0)
    reg sign_bit;
    assign sign_bit = (!l_unsigned) & ((lbhw_sel == 2'b00) ? i_dmem_rdata[7] : // byte access
                      (lbhw_sel == 2'b01) ? i_dmem_rdata[15] : // half-word access
                      (lbhw_sel == 2'b10) ? i_dmem_rdata[31] : 1'b0;) // word access

    reg [31:0] load_data;
    assign load_data = is_load ? ((lbhw_sel == 2'b00) ? {{24{sign_bit}}, i_dmem_rdata[7:0]} : // byte access
                       (lbhw_sel == 2'b01) ? {{16{sign_bit}}, i_dmem_rdata[15:0]} : // half-word access
                       (lbhw_sel == 2'b10) ? i_dmem_rdata : // word access
                       32'h0000_0000) : 32'h0000_0000; // default case that should never happen



    /// Store data logic ///
    always @(posedge i_clk) begin
        if (o_dmem_wen) begin
            case (sbhw_sel)
                2'b00: o_dmem_wdata <= {{24{rs2_rdata[7]}}, rs2_rdata[7:0]}; // byte access
                2'b01: o_dmem_wdata <= {16{rs2_rdata[15]}, rs2_rdata[15:0]}; // half-word access
                2'b10: o_dmem_wdata <= rs2_rdata; // word access
                default: o_dmem_wdata <= 32'h0000_0000; // default case that should never happen
            endcase
        end else begin
            o_dmem_wdata <= 32'h0000_0000; // when not writing, set wdata to 0
        end
    end

    assign mem_data = 32'd0;

    //writeback logic
    assign rd_wdata = o_men_to_reg ? men_data :
                      (is_jump) ? pc_add_4 : // for jal and jalr, we write the return address (pc + 4) to rd
                      alu_result; // for other instructions, we write the result of the ALU calculation to rd
    

endmodule

`default_nettype wire