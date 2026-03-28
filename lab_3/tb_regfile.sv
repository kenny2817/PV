`timescale 1ns/1ps

`ifndef DUT_NAME
    `define DUT_NAME regfile_v0
`endif

package constants
    int NUM_REG = 32;
    int DATA_WIDTH = 16;
    int ADDR_WIDTH = $clog2(NUM_REG);
endpackage

import constants::*;

interface regfile_if (
    input logic clk
);

    logic                      rst_n, wr_en, err;
    logic [ADDR_WIDTH - 1 : 0] wr_addr, rd_addr1, rd_addr2;
    logic [DATA_WIDTH - 1 : 0] wr_data, rd_data1, rd_data2;

    modport dut (
        input  rd_data1, rd_data2, err, clk,
        output rst_n, wr_en, wr_addr, wr_data, rd_addr1, rd_addr2
    );

endinterface

class regfile_mail;

    // INPUTS
    rand bit                      wr_en; 
    rand bit [ADDR_WIDTH - 1 : 0] wr_addr;
    rand bit [DATA_WIDTH - 1 : 0] wr_data;
    rand bit [ADDR_WIDTH - 1 : 0] rd_addr1;
    rand bit [ADDR_WIDTH - 1 : 0] rd_addr2;

    // OUTPUTS
    logic [DATA_WIDTH - 1 : 0]    rd_data1;
    logic [DATA_WIDTH - 1 : 0]    rd_data2;
    bit                           err;

endclass

class regfile_generator;
    
    mailbox #(regfile_mail) gen_drv_mbx;
    int num_transactions;

    function new(mailbox #(regfile_mail) gen_drv_mbx,
                 int num_transactions = 10,
                 int seed = 0);
        this.gen_drv_mbx = gen_drv_mbx;
        this.num_transactions = num_transactions;
        if (seed != 0) this.srandom(seed);
    endfunction

    task run();

        regfile_mail mail;

        for (int i = 0; i < num_transactions; i++) begin
            mail = new();
            
            if (!mail.randomize()) begin
                $error("Generator: Randomization failed!");
            end
            
            gen_drv_mbx.put(mail);
        end
        
    endtask

endclass

class regfile_driver;

    virtual interface regfile_if.dut regfile_If;
    mailbox #(regfile_mail) gen_drv_mbx;

    function new(virtual interface regfile_if.dut regfile_If,
                 mailbox #(regfile_mail) gen_drv_mbx);
        this.regfile_If = regfile_If;
        this.gen_drv_mbx = gen_drv_mbx;
    endfunction

    task run();
        regfile_mail mail;
        
        forever begin
            gen_drv_mbx.get(mail); 
            
            read_reg(mail.rd_addr1, mail.rd_addr2);
            
            if (mail.wr_en) write_reg(mail.wr_addr, mail.wr_data);
            else @(posedge regfile_If.clk);
        end

    endtask

    task init_dut();
    
        regfile_If.rst_n = 1'b1;
        regfile_If.wr_en = 1'b0;
        regfile_If.wr_addr <= 0;
        regfile_If.wr_data <= 0;
        regfile_If.rd_addr1 <= 0;
        regfile_If.rd_addr2 <= 0;

        this.reset();

    endtask

    task reset();

        regfile_If.rst_n = 1'b0;

        @(posedge regfile_If.clk);
        
        regfile_If.rst_n = 1'b1;

    endtask

    task write_reg(input int addr, input int data);

        regfile_If.wr_addr <= addr;
        regfile_If.wr_data <= data;
        regfile_If.wr_en   <= 1'b1;

        @(posedge regfile_If.clk);

        regfile_If.wr_en   <= 1'b0;

    endtask

    task read_reg(input int addr1, input int addr2);

        regfile_If.rd_addr1 <= addr1;
        regfile_If.rd_addr2 <= addr2;

    endtask

endclass

class regfile_monitor;

    virtual interface regfile_if.dut regfile_If;
    mailbox #(regfile_mail) mon_chk_mbx;

    function new(virtual interface regfile_if.dut regfile_If,
                 mailbox #(regfile_mail) mon_chk_mbx);
        this.regfile_If = regfile_If;       
        this.mon_chk_mbx = mon_chk_mbx;
    endfunction

    task run();
    
        regfile_mail mail;

        forever begin
            @(regfile_If.clk);

            mail.wr_en    = regfile_If.wr_en;
            mail.wr_addr  = regfile_If.wr_addr;
            mail.wr_data  = regfile_If.wr_data;
            mail.rd_addr1 = regfile_If.rd_addr1;
            mail.rd_addr2 = regfile_If.rd_addr2;
            mail.rd_data1 = regfile_If.rd_data1;
            mail.rd_data2 = regfile_If.rd_data2;
            mail.err      = regfile_If.err;
            
            mon_chk_mbx.put(mail);

            $display("Time: %6t | rst: %b | en: %b | wr_addr: %2d | wr_data: %0d | err: %b | rd_addr1: %2d | rd_addr2: %2d | rd_data1: %0d | rd_data2: %0d |",
                $time, regfile_If.rst_n, regfile_If.wr_en, regfile_If.wr_addr, regfile_If.wr_data, regfile_If.err, regfile_If.rd_addr1, regfile_If.rd_addr2, regfile_If.rd_data1, regfile_If.rd_data2);
        end 

    endtask

endclass

class regfile_scoreboard;

    mailbox #(regfile_mail) mon_scb_mbx;
    logic []

    function new(mailbox #(regfile_mail) mon_scb_mbx);
        this.mon_scb_mbx = mon_scb_mbx;
    endfunction

    task run();

        regfile_mail mail;

        forever begin

            mon_scb_mbx.get(mail);



            
        end

    endtask

endclass

module tb_regfile;

    logic clk;
    initial clk = 0;
    always #5 clk = ~clk;

    regfile_if regfile_If(clk);

    mailbox #(regfile_mail) gen_drv_mbx;
    mailbox #(regfile_mail) mon_chk_mbx;

    regfile_generator gen;
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

        gen_drv_mbx = new(1);
        mon_chk_mbx = new(); // unbounded

        gen = new(gen_drv_mbx, 10, 1234);
        drv = new(regfile_If, gen_drv_mbx);
        mon = new(regfile_If);

        fork
            drv.run();
            mon.run();
        join_none

        drv.init_dut();
        
        gen.run();

        repeat(5) @(posedge clk);

        $finish();
        
    end

endmodule
