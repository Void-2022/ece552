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

    ////////////////////////////////////////////////////////////////////////////////
    // 1. PIPELINED SIGNALS
    //
    // These are signals used by the pipeline registers.
    //
    // Format: <stage1>_<stage2>_<optional_retire>_<signal_name>
    //
    // Meaning: <signal_name> from the <stage1>/<stage2> pipeline register that does
    //          or does not eventually get piped to feed a retire signal for tests
    //
    // Example: if_id_retire_valid means the "valid" signal out of the IF/ID pipeline
    //          register (so, produced in the IF stage, piped to the ID stage), that
    //          will eventually be piped to feed into the retire signal bearing the
    //          same name (o_retire_valid)
    ////////////////////////////////////////////////////////////////////////////////


    reg [31:0] pc; // the PC is effectively a pipeline register piping next pc value to the fetch stage for fetching


    ////////////
    // IF/ID //
    //////////

    // Since now the processor is pipelined, we can't just set the retire valid to be 1 anymore
    // because an instruction is not being retired until the very first instruction end up
    // at the WB stage.
    //
    // Therefore this valid signal, being instruction-specific, has to be piped all the way down to
    // MEM/WB from IF/ID, for it to feed to o_retire_valid in the WB stage which is when it is being retired.
    reg        if_id_retire_valid;
    reg [31:0] if_id_retire_pc; // from pc
    reg [31:0] if_id_retire_inst;
    reg [31:0] if_id_pc4;


    ////////////
    // ID/EX //
    //////////
    reg        id_ex_retire_valid;
    reg [31:0] id_ex_retire_pc;
    reg [31:0] id_ex_retire_inst;
    reg [31:0] id_ex_pc4;

    // signals generated in the ID stage
    reg [31:0] id_ex_imm;
    reg [31:0] id_ex_retire_rs1_rdata;
    reg [31:0] id_ex_retire_rs2_rdata;
    reg [4:0]  id_ex_retire_rs1_raddr;
    reg [4:0]  id_ex_retire_rs2_raddr;
    reg [4:0]  id_ex_retire_rd_waddr;
    reg [2:0]  id_ex_funct3;
    reg [2:0]  id_ex_opsel;
    reg        id_ex_sub;
    reg        id_ex_unsigned;
    reg        id_ex_arith;
    reg        id_ex_mem_wen;
    reg        id_ex_alu_src1;
    reg        id_ex_alu_src2;
    reg [5:0]  id_ex_format;
    reg        id_ex_is_lui;
    reg [1:0]  id_ex_sbhw_sel;
    reg [1:0]  id_ex_lbhw_sel;
    reg        id_ex_l_unsigned;
    reg        id_ex_is_jump;
    reg        id_ex_is_branch;
    reg        id_ex_is_jal;
    reg        id_ex_is_jalr;
    reg        id_ex_is_load;
    reg        id_ex_retire_rd_wen;



    /////////////
    // EX/MEM //
    ///////////
    reg        ex_mem_retire_valid;
    reg [31:0] ex_mem_retire_pc;
    reg [31:0] ex_mem_retire_inst;
    reg [31:0] ex_mem_retire_next_pc;
    reg [31:0] ex_mem_pc4;
    reg [31:0] ex_mem_alu_result;
    reg [31:0] ex_mem_retire_rs1_rdata;
    reg [31:0] ex_mem_retire_rs2_rdata;
    reg [4:0]  ex_mem_retire_rs1_raddr;
    reg [4:0]  ex_mem_retire_rs2_raddr;
    reg [4:0]  ex_mem_retire_rd_waddr;
    reg        ex_mem_retire_rd_wen;
    reg        ex_mem_mem_wen;
    reg [1:0]  ex_mem_sbhw_sel;
    reg [1:0]  ex_mem_lbhw_sel;
    reg        ex_mem_l_unsigned;
    reg        ex_mem_is_jump;
    reg        ex_mem_is_load;
    reg        ex_mem_halt;
    reg        ex_mem_trap;


    /////////////
    // MEM/WB //
    ///////////
    reg        mem_wb_retire_valid;
    reg [31:0] mem_wb_retire_pc;
    reg [31:0] mem_wb_retire_inst;
    reg [31:0] mem_wb_retire_next_pc;
    reg [31:0] mem_wb_alu_result;
    reg [31:0] mem_wb_pc4;
    reg [31:0] mem_wb_load_result;
    reg [31:0] mem_wb_retire_rs1_rdata;
    reg [31:0] mem_wb_retire_rs2_rdata;
    reg [4:0]  mem_wb_retire_rs1_raddr;
    reg [4:0]  mem_wb_retire_rs2_raddr;
    reg [4:0]  mem_wb_retire_rd_waddr;
    reg        mem_wb_retire_rd_wen;
    reg        mem_wb_is_jump;
    reg        mem_wb_is_load;
    reg        mem_wb_retire_halt;
    reg        mem_wb_retire_trap;


    ////////////////////////////////////////////////////////////////////////////////
    // 2. COMBINATIONAL STAGE SIGNALS
    //
    // These are signals used in the datapath for each stage.
    //
    // Format: <stage>_<signal_name>
    ////////////////////////////////////////////////////////////////////////////////
     
    // No hazard detection/stalling/forwarding logic yet 
    // Use software-inserted NOP


    ////////////////////////////////////
    // FETCH COMB LOGIC - DRIVEN HERE //
    ////////////////////////////////////
    wire [31:0] if_inst;
    wire [31:0] if_pc_plus4;
    wire [31:0] if_next_pc;

    assign o_imem_raddr = pc; // address to fetch the instruction is the current pc
    assign if_inst = i_imem_rdata; // instruction fetched from imem
    assign if_pc_plus4 = pc + 32'd4;


    ////////////////////////////////////////////////////////////
    // ID COMB LOGIC - DRIVEN BY CONTROL, RF, AND IMM MODULES //
    ////////////////////////////////////////////////////////////
    wire [2:0] id_opsel;
    wire id_sub, id_unsigned, id_arith, id_mem_wen, id_alu_src1, id_alu_src2;
    wire [5:0] id_format;
    wire id_is_lui;
    wire [1:0] id_sbhw_sel, id_lbhw_sel;
    wire id_l_unsigned;
    wire id_is_jump, id_is_branch, id_is_jal, id_is_jalr, id_is_load, id_rd_wen;
    wire [31:0] id_imm;
    wire [31:0] id_rs1_rdata, id_rs2_rdata;


    //////////////////////////////////////////////////////////////////////////////
    // EX COMB LOGIC - DRIVEN IN A HUGE BLOCK UNDERNEATH ALONG WITH MEM AND WEB //
    //////////////////////////////////////////////////////////////////////////////
    wire [31:0] ex_op1, ex_op2, ex_alu_result;
    wire ex_eq, ex_slt, ex_b_sel;
    wire ex_taken_control; // that we're either jumping or taking a branch
    wire [31:0] ex_pc_add_imm;
    wire [31:0] ex_jalr_target;
    wire [31:0] ex_control_target;
    wire [31:0] ex_instr_next_pc;

    wire ex_halt_raw, ex_halt, ex_illegal_inst;
    wire ex_misaligned_load, ex_misaligned_store, ex_misaligned_next_pc, ex_trap;


    //////////////////////
    /// MEM COMB LOGIC //
    ////////////////////
    wire [3:0] load_mask;
    wire [3:0] store_mask;
    wire [3:0] dmem_mask_raw;
    wire [31:0] store_wdata_shifted;
    wire [31:0] load_shifted_data;
    wire [31:0] load_result_data;

    /////////////////////
    /// WB COMB LOGIC //
    ///////////////////
    wire [31:0] wb_rd_wdata;
    wire rd_wen_safe;


    ////////////////////////////////////////////////////////////////////////////////
    // 3. MODULE INSTANTIATIONS
    ////////////////////////////////////////////////////////////////////////////////
    control iControl (
        .i_inst(if_id_retire_inst),
        .o_rd_wen(id_rd_wen),
        .o_opsel(id_opsel),
        .o_sub(id_sub),
        .o_unsigned(id_unsigned),
        .o_arith(id_arith),
        .o_mem_wen(id_mem_wen),
        .o_alu_src_2(id_alu_src2),
        .o_format(id_format),
        .o_is_lui(id_is_lui),
        .o_alu_src_1(id_alu_src1),
        .sbhw_sel(id_sbhw_sel),
        .lbhw_sel(id_lbhw_sel),
        .l_unsigned(id_l_unsigned),
        .o_is_jump(id_is_jump),
        .is_branch(id_is_branch),
        .is_jal(id_is_jal),
        .is_jalr(id_is_jalr),
        .o_is_load(id_is_load)
    );

    imm iImm (
        .i_inst(if_id_retire_inst),
        .i_format(id_format),
        .o_immediate(id_imm)
    );

    // enable RF bypass for this no-hazard-detection pipeline version
    rf #(.BYPASS_EN(1)) iRF (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_rs1_raddr(if_id_retire_inst[19:15]),
        .o_rs1_rdata(id_rs1_rdata),
        .i_rs2_raddr(if_id_retire_inst[24:20]),
        .o_rs2_rdata(id_rs2_rdata),
        .i_rd_wen(rd_wen_safe),
        .i_rd_waddr(mem_wb_retire_rd_waddr),
        .i_rd_wdata(wb_rd_wdata)
    );

    alu iALU (
        .i_op1(ex_op1),
        .i_op2(ex_op2),
        .i_opsel(id_ex_opsel),
        .i_sub(id_ex_sub),
        .i_unsigned(id_ex_unsigned),
        .i_arith(id_ex_arith),
        .o_result(ex_alu_result),
        .o_eq(ex_eq),
        .o_slt(ex_slt)
    );

    branch_decoder iBD (
        .funct3(id_ex_funct3),
        .is_branch(id_ex_is_branch),
        .eq(ex_eq),
        .slt(ex_slt),
        .b_sel(ex_b_sel)
    );


    ////////////////////////////////////////////////////////////////////////////////
    // 4. EX/MEM/WB COMBINATIONAL ASSIGNS
    ////////////////////////////////////////////////////////////////////////////////

    assign ex_op1 = id_ex_alu_src1 ? (id_ex_is_lui ? 32'd0 : id_ex_retire_pc) : id_ex_retire_rs1_rdata;
    assign ex_op2 = id_ex_alu_src2 ? id_ex_retire_rs2_rdata : id_ex_imm;

    assign ex_taken_control = ex_b_sel || id_ex_is_jal || id_ex_is_jalr;
    assign ex_pc_add_imm = id_ex_retire_pc + id_ex_imm;
    assign ex_jalr_target = {ex_alu_result[31:1], 1'b0};
    assign ex_control_target = id_ex_is_jalr ? ex_jalr_target : ex_pc_add_imm;
    assign ex_instr_next_pc = ex_taken_control ? ex_control_target : id_ex_pc4;

    // ebreak op code is 1 1 1 0 0 1 1 and other bits are 0
    assign ex_halt_raw = (id_ex_retire_inst == 32'h00100073);
    assign ex_halt = id_ex_retire_valid && ex_halt_raw;


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
    assign ex_illegal_inst = id_ex_retire_valid && (id_ex_format == 6'b000000) && !ex_halt_raw;

    assign ex_misaligned_load = id_ex_retire_valid && id_ex_is_load && (
                                (id_ex_lbhw_sel == 2'b01 && ex_alu_result[0]) ||
                                (id_ex_lbhw_sel == 2'b10 && (ex_alu_result[1:0] != 2'b00)) ||
                                (id_ex_lbhw_sel == 2'b11)
                             );

    assign ex_misaligned_store = id_ex_retire_valid && id_ex_mem_wen && (
                                 (id_ex_sbhw_sel == 2'b01 && ex_alu_result[0]) ||
                                 (id_ex_sbhw_sel == 2'b10 && (ex_alu_result[1:0] != 2'b00)) ||
                                 (id_ex_sbhw_sel == 2'b11)
                              );

    assign ex_misaligned_next_pc = id_ex_retire_valid && ex_taken_control && (ex_control_target[1:0] != 2'b00);
    
    assign ex_trap = ex_illegal_inst || ex_misaligned_load || ex_misaligned_store || ex_misaligned_next_pc;



    // Branch/jump redirection is resolved in EX.
    assign if_next_pc = (id_ex_retire_valid && ex_taken_control) ? ex_control_target : if_pc_plus4;


    // Data memory access (MEM stage)
    // dmem takes in aligned addresses
    assign o_dmem_addr = {ex_mem_alu_result[31:2], 2'b00};
    assign o_dmem_ren = ex_mem_retire_valid && ex_mem_is_load && !ex_mem_trap;
    assign o_dmem_wen = ex_mem_retire_valid && ex_mem_mem_wen && !ex_mem_trap;


    // masks for load/store byte lanes - check long wall of text (line 53-72)
    // note unalligned data memory accesses are not handled here, but in trap logic
    assign load_mask = (ex_mem_lbhw_sel == 2'b00) ? ((ex_mem_alu_result[1:0] == 2'b00) ? 4'b0001 :
                                                      (ex_mem_alu_result[1:0] == 2'b01) ? 4'b0010 :
                                                      (ex_mem_alu_result[1:0] == 2'b10) ? 4'b0100 :
                                                                                          4'b1000) :
                       (ex_mem_lbhw_sel == 2'b01) ? (ex_mem_alu_result[1] ? 4'b1100 : 4'b0011) :
                       (ex_mem_lbhw_sel == 2'b10) ? 4'b1111 :
                                                     4'b0000;

    assign store_mask = (ex_mem_sbhw_sel == 2'b00) ? ((ex_mem_alu_result[1:0] == 2'b00) ? 4'b0001 :
                                                       (ex_mem_alu_result[1:0] == 2'b01) ? 4'b0010 :
                                                       (ex_mem_alu_result[1:0] == 2'b10) ? 4'b0100 :
                                                                                           4'b1000) :
                        (ex_mem_sbhw_sel == 2'b01) ? (ex_mem_alu_result[1] ? 4'b1100 : 4'b0011) :
                        (ex_mem_sbhw_sel == 2'b10) ? 4'b1111 :
                                                      4'b0000;

    assign dmem_mask_raw = ex_mem_is_load ? load_mask :
                           ex_mem_mem_wen ? store_mask :
                           4'b0000;

    assign o_dmem_mask = (!ex_mem_retire_valid || ex_mem_trap) ? 4'b0000 : dmem_mask_raw; // unsure if needed

    // shift rs2 into the selected byte lanes for store's writes
    assign store_wdata_shifted = (ex_mem_alu_result[1:0] == 2'b00) ? ex_mem_retire_rs2_rdata :
                                 (ex_mem_alu_result[1:0] == 2'b01) ? {ex_mem_retire_rs2_rdata[23:0], 8'b0} :
                                 (ex_mem_alu_result[1:0] == 2'b10) ? {ex_mem_retire_rs2_rdata[15:0], 16'b0} :
                                                                       {ex_mem_retire_rs2_rdata[7:0], 24'b0};

    assign o_dmem_wdata = store_wdata_shifted;

    // align selected byte lane to bits [7:0] before extension
    // ("only x bytes can be assumed to have valid data")
    assign load_shifted_data = (ex_mem_alu_result[1:0] == 2'b00) ? i_dmem_rdata :
                               (ex_mem_alu_result[1:0] == 2'b01) ? {8'b0,  i_dmem_rdata[31:8]} :
                               (ex_mem_alu_result[1:0] == 2'b10) ? {16'b0, i_dmem_rdata[31:16]} :
                                                                     {24'b0, i_dmem_rdata[31:24]};

    // load data selection and sign/zero extension
    // ("shift the rdata word right by x bits and sign/zero extend as appropriate")
    assign load_result_data = (ex_mem_lbhw_sel == 2'b00) ? // lb/lbu
                            (ex_mem_l_unsigned ? {24'b0, load_shifted_data[7:0]} :
                                                 {{24{load_shifted_data[7]}}, load_shifted_data[7:0]}) :
                            (ex_mem_lbhw_sel == 2'b01) ? // lh/lhu
                            (ex_mem_l_unsigned ? {16'b0, load_shifted_data[15:0]} :
                                                 {{16{load_shifted_data[15]}}, load_shifted_data[15:0]}) :
                            (ex_mem_lbhw_sel == 2'b10) ? // lw
                            load_shifted_data :
                            32'b0;

    // Register writeback mux
    assign wb_rd_wdata = mem_wb_is_load ? mem_wb_load_result :
                         mem_wb_is_jump ? mem_wb_pc4 :
                         mem_wb_alu_result;

    assign rd_wen_safe = mem_wb_retire_valid && mem_wb_retire_rd_wen && !mem_wb_retire_halt && !mem_wb_retire_trap;




    //////////////////////////
    //// 5. RETIRE LOGIC ////
    ////////////////////////


    ////////////////////////////////
    // RETIRE OUTPUTS (WB STAGE) //
    //////////////////////////////
    assign o_retire_valid = mem_wb_retire_valid;
    assign o_retire_inst = mem_wb_retire_inst;
    assign o_retire_halt = mem_wb_retire_halt;
    assign o_retire_trap = mem_wb_retire_trap;


    //////////////////////////
    /// RETIRE LOGIC - RF ///
    ////////////////////////
    assign o_retire_rs1_raddr = mem_wb_retire_rs1_raddr;
    assign o_retire_rs1_rdata = mem_wb_retire_rs1_rdata;
    assign o_retire_rs2_raddr = mem_wb_retire_rs2_raddr;
    assign o_retire_rs2_rdata = mem_wb_retire_rs2_rdata;

    // retire writeback info from WB stage (rd_waddr is zero when no reg write retires)
    assign o_retire_rd_waddr = rd_wen_safe ? mem_wb_retire_rd_waddr : 5'd0;
    assign o_retire_rd_wdata = wb_rd_wdata;

    //////////////////////////
    /// RETIRE LOGIC - PC ///
    ////////////////////////
    assign o_retire_pc = mem_wb_retire_pc;
    assign o_retire_next_pc = mem_wb_retire_next_pc;


    ////////////////////////////////////////////////////////////////////////////////
    // 6. PIPELINE REGISTERS
    ////////////////////////////////////////////////////////////////////////////////

    // PC register (IF)
    always @(posedge i_clk) begin
        if (i_rst) begin
            pc <= RESET_ADDR;
        end else begin
            pc <= if_next_pc;
        end
    end

    // IF/ID pipeline register
    always @(posedge i_clk) begin
        if (i_rst) begin
            if_id_retire_valid <= 1'b0;
            if_id_retire_pc <= 32'd0;
            if_id_retire_inst <= 32'd0;
            if_id_pc4 <= 32'd0;
        end else begin
            if_id_retire_valid <= 1'b1;
            if_id_retire_pc <= pc;
            if_id_retire_inst <= if_inst;
            if_id_pc4 <= if_pc_plus4;
        end
    end

    // ID/EX pipeline register
    always @(posedge i_clk) begin
        if (i_rst) begin
            id_ex_retire_valid <= 1'b0;
            id_ex_retire_pc <= 32'd0;
            id_ex_retire_inst <= 32'd0;
            id_ex_pc4 <= 32'd0;
            id_ex_imm <= 32'd0;
            id_ex_retire_rs1_rdata <= 32'd0;
            id_ex_retire_rs2_rdata <= 32'd0;
            id_ex_retire_rs1_raddr <= 5'd0;
            id_ex_retire_rs2_raddr <= 5'd0;
            id_ex_retire_rd_waddr <= 5'd0;
            id_ex_funct3 <= 3'd0;
            id_ex_opsel <= 3'd0;
            id_ex_sub <= 1'b0;
            id_ex_unsigned <= 1'b0;
            id_ex_arith <= 1'b0;
            id_ex_mem_wen <= 1'b0;
            id_ex_alu_src1 <= 1'b0;
            id_ex_alu_src2 <= 1'b0;
            id_ex_format <= 6'd0;
            id_ex_is_lui <= 1'b0;
            id_ex_sbhw_sel <= 2'd0;
            id_ex_lbhw_sel <= 2'd0;
            id_ex_l_unsigned <= 1'b0;
            id_ex_is_jump <= 1'b0;
            id_ex_is_branch <= 1'b0;
            id_ex_is_jal <= 1'b0;
            id_ex_is_jalr <= 1'b0;
            id_ex_is_load <= 1'b0;
            id_ex_retire_rd_wen <= 1'b0;
        end else begin
            id_ex_retire_valid <= if_id_retire_valid;
            id_ex_retire_pc <= if_id_retire_pc;
            id_ex_retire_inst <= if_id_retire_inst;
            id_ex_pc4 <= if_id_pc4;
            id_ex_imm <= id_imm;
            id_ex_retire_rs1_rdata <= id_rs1_rdata;
            id_ex_retire_rs2_rdata <= id_rs2_rdata;
            id_ex_retire_rs1_raddr <= if_id_retire_inst[19:15];
            id_ex_retire_rs2_raddr <= if_id_retire_inst[24:20];
            id_ex_retire_rd_waddr <= if_id_retire_inst[11:7];
            id_ex_funct3 <= if_id_retire_inst[14:12];
            id_ex_opsel <= id_opsel;
            id_ex_sub <= id_sub;
            id_ex_unsigned <= id_unsigned;
            id_ex_arith <= id_arith;
            id_ex_mem_wen <= id_mem_wen;
            id_ex_alu_src1 <= id_alu_src1;
            id_ex_alu_src2 <= id_alu_src2;
            id_ex_format <= id_format;
            id_ex_is_lui <= id_is_lui;
            id_ex_sbhw_sel <= id_sbhw_sel;
            id_ex_lbhw_sel <= id_lbhw_sel;
            id_ex_l_unsigned <= id_l_unsigned;
            id_ex_is_jump <= id_is_jump;
            id_ex_is_branch <= id_is_branch;
            id_ex_is_jal <= id_is_jal;
            id_ex_is_jalr <= id_is_jalr;
            id_ex_is_load <= id_is_load;
            id_ex_retire_rd_wen <= id_rd_wen;
        end
    end

    // EX/MEM pipeline register
    always @(posedge i_clk) begin
        if (i_rst) begin
            ex_mem_retire_valid <= 1'b0;
            ex_mem_retire_pc <= 32'd0;
            ex_mem_retire_inst <= 32'd0;
            ex_mem_retire_next_pc <= 32'd0;
            ex_mem_pc4 <= 32'd0;
            ex_mem_alu_result <= 32'd0;
            ex_mem_retire_rs1_rdata <= 32'd0;
            ex_mem_retire_rs2_rdata <= 32'd0;
            ex_mem_retire_rs1_raddr <= 5'd0;
            ex_mem_retire_rs2_raddr <= 5'd0;
            ex_mem_retire_rd_waddr <= 5'd0;
            ex_mem_retire_rd_wen <= 1'b0;
            ex_mem_mem_wen <= 1'b0;
            ex_mem_sbhw_sel <= 2'd0;
            ex_mem_lbhw_sel <= 2'd0;
            ex_mem_l_unsigned <= 1'b0;
            ex_mem_is_jump <= 1'b0;
            ex_mem_is_load <= 1'b0;
            ex_mem_halt <= 1'b0;
            ex_mem_trap <= 1'b0;
        end else begin
            ex_mem_retire_valid <= id_ex_retire_valid;
            ex_mem_retire_pc <= id_ex_retire_pc;
            ex_mem_retire_inst <= id_ex_retire_inst;
            ex_mem_retire_next_pc <= ex_instr_next_pc;
            ex_mem_pc4 <= id_ex_pc4;
            ex_mem_alu_result <= ex_alu_result;
            ex_mem_retire_rs1_rdata <= id_ex_retire_rs1_rdata;
            ex_mem_retire_rs2_rdata <= id_ex_retire_rs2_rdata;
            ex_mem_retire_rs1_raddr <= id_ex_retire_rs1_raddr;
            ex_mem_retire_rs2_raddr <= id_ex_retire_rs2_raddr;
            ex_mem_retire_rd_waddr <= id_ex_retire_rd_waddr;
            ex_mem_retire_rd_wen <= id_ex_retire_rd_wen;
            ex_mem_mem_wen <= id_ex_mem_wen;
            ex_mem_sbhw_sel <= id_ex_sbhw_sel;
            ex_mem_lbhw_sel <= id_ex_lbhw_sel;
            ex_mem_l_unsigned <= id_ex_l_unsigned;
            ex_mem_is_jump <= id_ex_is_jump;
            ex_mem_is_load <= id_ex_is_load;
            ex_mem_halt <= ex_halt;
            ex_mem_trap <= ex_trap;
        end
    end

    // MEM/WB pipeline register
    always @(posedge i_clk) begin
        if (i_rst) begin
            mem_wb_retire_valid <= 1'b0;
            mem_wb_retire_pc <= 32'd0;
            mem_wb_retire_inst <= 32'd0;
            mem_wb_retire_next_pc <= 32'd0;
            mem_wb_alu_result <= 32'd0;
            mem_wb_pc4 <= 32'd0;
            mem_wb_load_result <= 32'd0;
            mem_wb_retire_rs1_rdata <= 32'd0;
            mem_wb_retire_rs2_rdata <= 32'd0;
            mem_wb_retire_rs1_raddr <= 5'd0;
            mem_wb_retire_rs2_raddr <= 5'd0;
            mem_wb_retire_rd_waddr <= 5'd0;
            mem_wb_retire_rd_wen <= 1'b0;
            mem_wb_is_jump <= 1'b0;
            mem_wb_is_load <= 1'b0;
            mem_wb_retire_halt <= 1'b0;
            mem_wb_retire_trap <= 1'b0;
        end else begin
            mem_wb_retire_valid <= ex_mem_retire_valid;
            mem_wb_retire_pc <= ex_mem_retire_pc;
            mem_wb_retire_inst <= ex_mem_retire_inst;
            mem_wb_retire_next_pc <= ex_mem_retire_next_pc;
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_pc4 <= ex_mem_pc4;
            mem_wb_load_result <= load_result_data;
            mem_wb_retire_rs1_rdata <= ex_mem_retire_rs1_rdata;
            mem_wb_retire_rs2_rdata <= ex_mem_retire_rs2_rdata;
            mem_wb_retire_rs1_raddr <= ex_mem_retire_rs1_raddr;
            mem_wb_retire_rs2_raddr <= ex_mem_retire_rs2_raddr;
            mem_wb_retire_rd_waddr <= ex_mem_retire_rd_waddr;
            mem_wb_retire_rd_wen <= ex_mem_retire_rd_wen;
            mem_wb_is_jump <= ex_mem_is_jump;
            mem_wb_is_load <= ex_mem_is_load;
            mem_wb_retire_halt <= ex_mem_halt;
            mem_wb_retire_trap <= ex_mem_trap;
        end
    end

endmodule

`default_nettype wire
