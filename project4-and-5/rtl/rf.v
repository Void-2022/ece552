`default_nettype none

// The register file is effectively a single cycle memory with 32-bit words
// and depth 32. It has two asynchronous read ports, allowing two independent
// registers to be read at the same time combinationally, and one synchronous
// write port, allowing a register to be written to on the next clock edge.
// The register `x0` is hardwired to zero, and writes to it are ignored.
module rf #(
    // When this parameter is set to 1, "RF bypass" mode is enabled. This
    // allows data at the write port to be observed at the read ports
    // immediately without having to wait for the next clock edge. This is
    // a common forwarding optimization in a pipelined core (project 5), but
    // will cause a single-cycle processor to behave incorrectly.
    //
    // You are required to implement and test both modes. In project 3 and 4,
    // you will set this to 0, before enabling it in project 5.
    parameter BYPASS_EN = 0
) (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // Both read register ports are asynchronous (zero-cycle). That is, read
    // data is visible combinationally without having to wait for a clock.
    //
    // Register read port 1, with input address [0, 31] and output data.
    input  wire [ 4:0] i_rs1_raddr,
    output wire [31:0] o_rs1_rdata,
    // Register read port 2, with input address [0, 31] and output data.
    input  wire [ 4:0] i_rs2_raddr,
    output wire [31:0] o_rs2_rdata,
    // The register write port is synchronous. When write is enabled, the
    // write data is visible after the next clock edge.
    //
    // Write register enable, address [0, 31] and input data.
    input  wire        i_rd_wen,
    input  wire [ 4:0] i_rd_waddr,
    input  wire [31:0] i_rd_wdata
);
    // TODO: Fill in your implementation here.
    // Contain 32 (deep) 32-bit (wide) registers, with the lowest indexed register (x0, or zero) hardwired to 0x00000000.
    // Be capable of reading two registers per cycle and writing one register per cycle.
    // Allow a bypass mode, which when enabled, allows a write to be observed at the read ports in the same cycle it is to be executed (see starter file comments).
    // You may also use behavioral (loops, if/else) Verilog for this problem only.
    reg [31:0] rf [31:0];

    generate
        if (BYPASS_EN) begin : gen_bypass
            //bypass logic
            
                //register 1
                //if the write enable is high and the write address matches the read address, bypass the write data to the read data
            assign o_rs1_rdata = (i_rd_wen && (i_rd_waddr == i_rs1_raddr) && (i_rs1_raddr != 5'b0)) ?
                             i_rd_wdata : ((i_rs1_raddr == 5'b0) ? 32'b0 : rf[i_rs1_raddr]);

                //register 2
            assign o_rs2_rdata = (i_rd_wen && (i_rd_waddr == i_rs2_raddr) && (i_rs2_raddr != 5'b0)) ?
                             i_rd_wdata : ((i_rs2_raddr == 5'b0) ? 32'b0 : rf[i_rs2_raddr]);

        end
        else begin : gen_no_bypass
            //no bypass logic, do nothing
            //if the read address is 0, the read data is 0 (hardwired to zero)
            //otherwise, read the data from the register file
            
            assign o_rs1_rdata = (i_rs1_raddr == 5'b0) ? 32'b0 : rf[i_rs1_raddr];
            assign o_rs2_rdata = (i_rs2_raddr == 5'b0) ? 32'b0 : rf[i_rs2_raddr];
            
        end
    endgenerate
    integer i;
    //synchronous write logic
    always @(posedge i_clk) begin
        //sychronous active high reset
        if (i_rst) begin
            //I though the for loop will be unrolled though
            //hardcode all the resgister to 0 on reset, even though x0 is already hardwired to 0, for simplicity of testing
            rf[0] <= 32'b0;
            rf[1] <= 32'b0;
            rf[2] <= 32'b0;
            rf[3] <= 32'b0;
            rf[4] <= 32'b0;
            rf[5] <= 32'b0;
            rf[6] <= 32'b0;
            rf[7] <= 32'b0;
            rf[8] <= 32'b0;
            rf[9] <= 32'b0;
            rf[10] <= 32'b0;    
            rf[11] <= 32'b0;
            rf[12] <= 32'b0;
            rf[13] <= 32'b0;
            rf[14] <= 32'b0;
            rf[15] <= 32'b0;
            rf[16] <= 32'b0;
            rf[17] <= 32'b0;
            rf[18] <= 32'b0;
            rf[19] <= 32'b0;
            rf[20] <= 32'b0;
            rf[21] <= 32'b0;
            rf[22] <= 32'b0;
            rf[23] <= 32'b0;
            rf[24] <= 32'b0;
            rf[25] <= 32'b0;
            rf[26] <= 32'b0;
            rf[27] <= 32'b0;
            rf[28] <= 32'b0;
            rf[29] <= 32'b0;
            rf[30] <= 32'b0;
            rf[31] <= 32'b0;
        end
        else if (i_rd_wen && (i_rd_waddr != 5'b0)) begin
            //write data to the register file, if the write enable is high and the write address is not 0 (x0 is hardwired to 0)
            rf[i_rd_waddr] <= i_rd_wdata;
        end
    end
endmodule

`default_nettype wire
