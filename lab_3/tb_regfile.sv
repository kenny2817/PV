`timescale 1ns/1ps

`ifndef DUT_NAME
    `define DUT_NAME regfile_v0
`endif

package constants;
    localparam int NUM_REG = 32;
    localparam int DATA_WIDTH = 16;
    localparam int ADDR_WIDTH = $clog2(NUM_REG);
endpackage

import constants::*;

interface regfile_if (input logic clk);

    logic                      rst_n, wr_en, err;
    logic [ADDR_WIDTH - 1 : 0] wr_addr, rd_addr1, rd_addr2;
    logic [DATA_WIDTH - 1 : 0] wr_data, rd_data1, rd_data2;

    logic is_illegal;

    modport dut (
        input  rd_data1, rd_data2, err, clk,
        output rst_n, wr_en, wr_addr, wr_data, rd_addr1, rd_addr2, is_illegal
    );

    assign is_illegal = rd_addr1 == rd_addr2 || (wr_en && (wr_addr == rd_addr1 || wr_addr == rd_addr2));

    property p_err_high;
        @(posedge clk) disable iff (!rst_n)
        is_illegal |=> (err == 1'b1);
    endproperty

    property p_err_low;
        @(posedge clk) disable iff (!rst_n)
        !is_illegal |=> (err == 1'b0);
    endproperty

    assert property (p_err_high)
        else $error("FAIL: err not high");
    assert property (p_err_low)
        else $error("HW FAIL: err not low");

endinterface

class regfile_mail;

    // RESET
    bit                           rst_n;

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

    // METADATA
    bit is_illegal;

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
    mailbox #(regfile_mail) mon_scb_mbx;
    mailbox #(regfile_mail) mon_chk_mbx;

    function new(virtual interface regfile_if.dut regfile_If,
                 mailbox #(regfile_mail) mon_scb_mbx,
                 mailbox #(regfile_mail) mon_chk_mbx);
        this.regfile_If = regfile_If;
        this.mon_scb_mbx = mon_scb_mbx;
        this.mon_chk_mbx = mon_chk_mbx;
    endfunction

    task run();
    
        regfile_mail mail;

        forever begin
            @(posedge regfile_If.clk);

            mail = new();
            mail.rst_n      = regfile_If.rst_n;
            mail.wr_en      = regfile_If.wr_en;
            mail.wr_addr    = regfile_If.wr_addr;
            mail.wr_data    = regfile_If.wr_data;
            mail.rd_addr1   = regfile_If.rd_addr1;
            mail.rd_addr2   = regfile_If.rd_addr2;
            mail.rd_data1   = regfile_If.rd_data1;
            mail.rd_data2   = regfile_If.rd_data2;
            mail.err        = regfile_If.err;
            mail.is_illegal = regfile_If.is_illegal;
            
            mon_scb_mbx.put(mail);
            mon_chk_mbx.put(mail);

            $display("Time: %6t | rst: %b | en: %b | wr_addr: %2d | wr_data: %0d | err: %b | rd_addr1: %2d | rd_addr2: %2d | rd_data1: %0d | rd_data2: %0d |",
                $time, regfile_If.rst_n, regfile_If.wr_en, regfile_If.wr_addr, regfile_If.wr_data, regfile_If.err, regfile_If.rd_addr1, regfile_If.rd_addr2, regfile_If.rd_data1, regfile_If.rd_data2);
        end 

    endtask

endclass

class regfile_scoreboard;

    mailbox #(regfile_mail) mon_scb_mbx;
    regfile_mail mail;

    logic [DATA_WIDTH - 1 : 0] golden_model_data[NUM_REG];

    int success_count_a = 0, error_count_a = 0;
    int success_count_b = 0, error_count_b = 0;
    int success_count_c = 0, error_count_c = 0;

    function void reset();
        for (int i = 0; i < NUM_REG; i++) begin
            golden_model_data[i] = '0;
        end
    endfunction

    function new(mailbox #(regfile_mail) mon_scb_mbx);
        this.mon_scb_mbx = mon_scb_mbx;
        this.reset();
    endfunction

    task check_illegal_rd();

            // check read data 1 and 2
            assert (mail.rd_data1 === 16'bx && mail.rd_data2 === 16'bx) begin
                success_count_a = success_count_a + 1;
            end else begin
                $error("Read 1-2 failed: %0h != x | %0h != x", mail.rd_data1, mail.rd_data2);
                error_count_a = error_count_a + 1;
            end

    endtask

    task check_legal_rd();

        // check read data 1
        assert(golden_model_data[mail.rd_addr1] == mail.rd_data1) begin
            success_count_b = success_count_b + 1;
        end else begin
            $error("Read 1 failed: %0h != %0h",
                    golden_model_data[mail.rd_addr1],
                    mail.rd_data1);
            error_count_b = error_count_b + 1;
        end

        // check read data 2
        assert(golden_model_data[mail.rd_addr2] == mail.rd_data2) begin
            success_count_c = success_count_c + 1;
        end else begin
            $error("Read 2 failed: %0h != %0h",
                    golden_model_data[mail.rd_addr2],
                    mail.rd_data2);
            error_count_c = error_count_c + 1;
        end

    endtask

    task check_rd();
        if (mail.is_illegal)  check_illegal_rd();
        if (!mail.is_illegal) check_legal_rd();
    endtask


    task run();

        forever begin

            mon_scb_mbx.get(mail);

            check_rd();

            // update golden model if legal write
            if (!mail.is_illegal) golden_model_data[mail.wr_addr] = mail.wr_data;
            
            // reset scoreboard if reset low
            if (!mail.rst_n) reset();
        end
    endtask

    function void print_error_count();

        int success_count = success_count_a + success_count_b + success_count_c;
        int err_count     = error_count_a + error_count_b + error_count_c;

        $display("********************************");
        $display("* success / errors: %d / %d *", success_count, err_count);
        $display("********************************");
        $display("*  illegal read: %d / %d *", success_count_a, error_count_a);
        $display("* legal read 1: %d / %d *", success_count_b, error_count_b);
        $display("* legal read 2: %d / %d *", success_count_c, error_count_c);
        $display("********************************");

    endfunction

endclass

module tb_regfile;

    logic clk;
    initial clk = 0;
    always #5 clk = ~clk;

    regfile_if regfile_If(clk);

    mailbox #(regfile_mail) gen_drv_mbx;
    mailbox #(regfile_mail) mon_scb_mbx;
    mailbox #(regfile_mail) mon_chk_mbx;

    regfile_generator   gen;
    regfile_driver      drv;
    regfile_monitor     mon;
    regfile_scoreboard  scb;

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
        mon_scb_mbx = new(); // unbounded
        mon_chk_mbx = new(); // unbounded

        gen = new(gen_drv_mbx, 10, 1234);
        drv = new(regfile_If, gen_drv_mbx);
        mon = new(regfile_If, mon_scb_mbx, mon_chk_mbx);
        scb = new(mon_scb_mbx);

        drv.init_dut();

        fork
            drv.run();
            mon.run();
            scb.run();
        join_none
        
        gen.run();

        repeat(5) @(posedge clk);

        scb.print_error_count();
        $finish();
    end

endmodule
