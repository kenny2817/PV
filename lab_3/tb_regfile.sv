`timescale 1ns/1ps

`ifndef DUT_NAME
    `define DUT_NAME regfile_v0
`endif

interface regfile_if #(
    parameter int NUM_REG = 32,
    parameter int DATA_WIDTH = 16
) (
    input logic clk
);

    localparam int ADDR_WIDTH = $clog2(NUM_REG);

    logic                      rst_n, wr_en, err;
    logic [ADDR_WIDTH - 1 : 0] wr_addr, rd_addr1, rd_addr2;
    logic [DATA_WIDTH - 1 : 0] wr_data, rd_data1, rd_data2;

    modport dut (
        input  rd_data1, rd_data2, err, clk
        output rst_n, wr_en, wr_addr, wr_data, rd_addr1, rd_addr2
    );

endinterface

class regfile_driver;

    virtual interface regfile_if.dut regfile_If;

    function new(virtual interface regfile_if.dut regfile_If);
        this.regfile_If = regfile_If;       
    endfunction

    task reset();

        regfile_If.rst_n = 1'b0;

        @(regfile_If.clk);
        
        regfile_If.rst_n = 1'b1;

    endtask

    task write_reg(input int addr, input int data);

        @(regfile_If.clk);

        regfile_If.wr_addr <= addr;
        regfile_If.wr_data <= data;
        regfile_If.wr_en   <= 1'b1;

        @(regfile_If.clk);

        regfile_If.wr_en   <= 1'b0;

    endtask

    task read_reg(input int addr1, input int addr2);

        regfile_If.rd_addr1 <= addr1;
        regfile_If.rd_addr2 <= addr2;

    endtask

endclass

class regfile_monitor;

    virtual interface regfile_if.dut regfile_If;

    function new(virtual interface regfile_if.dut regfile_If);
        this.regfile_If = regfile_If;       
    endfunction

    task monitor_signals();

        forever begin
            @(regfile_If.clk);
            $display("Time: %0t | rst: %b | en: %b | err: %b | rd_addr1: %0d | rd_addr2: %0d | rd_data1: %0d | rd_data2: %0d |",
                $time, regfile_If.rst_n, regfile_If.wr_en, regfile_If.err, regfile_If.rd_addr1, regfile_If.rd_addr2, regfile_If.rd_data1, regfile_If.rd_data2);
        end 

    endtask

endclass

module tb_regfile;

    logic clk;
    initial clk = 0;
    always #5 clk = ~clk;

    regfile_if regfile_If(clk);

    regfile_driver drv;
    regfile_monitor mon;

    `DUT_NAME dut (
        .clk      (clk),
        .rst_n    (regfile_If.rst_n),
        .wr_en    (regfile_If.wr_en),
        .wr_addr  (regfile_If.wr_addr),
        .wr_data  (regfile_If.wr_data),
        .rd_addr1 (regfile_If.rd_addr1),
        .rd_data1 (regfile_If.rd_data1),
        .rd_addr2 (regfile_If.rd_addr2),
        .rd_data2 (regfile_If.rd_data2),
        .err      (regfile_If.err)
    );

    initial begin
        drv = new(regfile_If);
        mon = new(regfile_If);

        fork
            mon.monitor_signals();
        join_none

        repeat(20) @(posedge clk);
        $finish();
    end

endmodule
