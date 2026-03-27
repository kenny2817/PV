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

    clocking drv_cb @(posedge clk);
        default input #0 output #0;
        output rst_n, wr_en, wr_addr, wr_data; 
    endclocking

    modport tb (
        clocking drv_cb,           
        output rd_addr1, rd_addr2,
        input  rd_data1, rd_data2, err
    );

endinterface

class regfile_driver;

    virtual interface regfile_if.tb regfile_If;

    function new(virtual interface regfile_if.tb regfile_If);
        this.regfile_If = regfile_If;       
    endfunction

    task reset();

        regfile_If.rst_n = 1'b0;

        @(regfile_If.drv_cb);
        
        regfile_If.rst_n = 1'b1;

    endtask

    task write_reg(input int addr, input int data);

        @(regfile_If.drv_cb);

        regfile_If.drv_cb.wr_addr <= addr;
        regfile_If.drv_cb.wr_data <= data;
        regfile_If.drv_cb.wr_en   <= 1'b1;

        @(regfile_If.drv_cb);

        regfile_If.drv_cb.wr_en   <= 1'b0;

    endtask

    task read_reg(input int addr1, input int addr2);

        regfile_If.drv_cb.rd_addr1 <= addr1;
        regfile_If.drv_cb.rd_addr2 <= addr2;

    endtask

endclass

class regfile_monitor();

    virtual interface regfile_if.tb regfile_If;

    function new(virtual interface regfile_if.tb regfile_If);
        this.regfile_If = regfile_If;       
    endfunction

    task monitor_signals();

        forever begin
            @(regfile_If.drv_cb);
            $display("Time: %0t | rst: %b | en: %b | err: %b | rd_addr1: %0d | rd_addr2: %0d | rd_data1: %0d | rd_data2: %0d |",
                $time, regfile_If.rst_n, regfile_If.wr_en, regfile_If.err, regfile_If.rd_addr1, regfile_If.rd_addr2, regfile_If.rd_data1, regfile_If.rd_data2);
        end 

    endtask

module tb_regfile;

    logic clk;
    initial clk = 0;
    always #5 clk = ~clk;

    regfile_if regfile_If(clk);

    `DUT_NAME dut (regfile_If.tb);

    initial begin
        repeat(20) @(posedge clk);
        $finish();
    end

endmodule
