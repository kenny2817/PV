`timescale 1ns/1ps

`ifndef DUT_NAME
    `define DUT_NAME regfile_v0
`endif

package constants;
    localparam int NUM_REG = 32;
    localparam int DATA_WIDTH = 16;
    localparam int ADDR_WIDTH = $clog2(NUM_REG);
    localparam int NUM_DIRECTED_TESTS = 8;
    localparam int NUM_RANDOMIZED_TESTS = 100000;
    localparam int SCB_CHECKS = 4;
    localparam int CHK_CHECKS = 2;

    function automatic void print_test_config();
        $display("*************************************");
        $display("* Directed tests:            %6d *", NUM_DIRECTED_TESTS);
        $display("*************************************");
        $display("* Randomized tests:          %6d *", NUM_RANDOMIZED_TESTS);
        $display("*************************************");
    endfunction

endpackage

import constants::*;

interface regfile_interface (input logic clk);

    logic                      rst_n, wr_en, err;
    logic [ADDR_WIDTH - 1 : 0] wr_addr, rd_addr1, rd_addr2;
    logic [DATA_WIDTH - 1 : 0] wr_data, rd_data1, rd_data2;

    clocking cb @(posedge clk);

        default input #1step output #0; 

        input  rd_data1, rd_data2, err;

        inout rst_n, wr_en, wr_addr, wr_data, rd_addr1, rd_addr2;

    endclocking

endinterface

class regfile_mail;

    // INPUTS
    rand bit                      rst_n;
    rand bit                      wr_en; 
    rand bit [ADDR_WIDTH - 1 : 0] wr_addr;
    rand bit [DATA_WIDTH - 1 : 0] wr_data;
    rand bit [ADDR_WIDTH - 1 : 0] rd_addr1;
    rand bit [ADDR_WIDTH - 1 : 0] rd_addr2;

    // OUTPUTS
    logic [DATA_WIDTH - 1 : 0]    rd_data1;
    logic [DATA_WIDTH - 1 : 0]    rd_data2;
    bit                           err;

    constraint c_rst_n {
        rst_n dist { 1'b0 := 5, 1'b1 := 95 }; 
    }

    constraint c_wr_en {
        wr_en dist { 1'b1 := 50, 1'b0 := 50 };
    }

    constraint c_data_corners {
        wr_data dist {
            16'h0000 := 1,
            16'hFFFF := 1,
            16'hAAAA := 1,
            16'h5555 := 1,
            [0:16'hFFFF] :/ 100 - 4
        };
    }

    constraint c_addr_collisions {
        rd_addr1 dist { rd_addr2 := 2, [0:31] :/ 8 };
        wr_addr dist { rd_addr1 := 1, rd_addr2 := 1, [0:31] :/ 8 };
    }

    function bit is_illegal();

        if (rd_addr1 == rd_addr2 || wr_en && (wr_addr == rd_addr1 || wr_addr == rd_addr2)) return 1'b1;        
        else                                                                               return 1'b0;
    
    endfunction

endclass

class regfile_generator;
    
    mailbox #(regfile_mail) gen_drv_mbx;
    int num_transactions;

    function new(mailbox #(regfile_mail) gen_drv_mbx,
                 int num_transactions = 10);
        this.gen_drv_mbx = gen_drv_mbx;
        this.num_transactions = num_transactions;
    endfunction

    task run();

        regfile_mail mail;

        repeat(num_transactions) begin
            mail = new();
            
            if (!mail.randomize()) begin
                $error("Generator: Randomization failed!");
            end
            
            gen_drv_mbx.put(mail);
        end
        
    endtask

    task send_mail(
        bit                      rst_n,
        bit                      wr_en,
        bit [ADDR_WIDTH - 1 : 0] wr_addr,
        bit [DATA_WIDTH - 1 : 0] wr_data,
        bit [ADDR_WIDTH - 1 : 0] rd_addr1,
        bit [ADDR_WIDTH - 1 : 0] rd_addr2
    );

        regfile_mail mail = new();

        mail.rst_n = rst_n;
        mail.wr_en = wr_en;
        mail.wr_addr = wr_addr;
        mail.wr_data = wr_data;
        mail.rd_addr1 = rd_addr1;
        mail.rd_addr2 = rd_addr2;

        gen_drv_mbx.put(mail);

    endtask

    task T_000();

        regfile_mail mail;

        for (int i = 0; i < 10; i++) begin
            send_mail(1'b1, 1'b1, i, i + 16'h1000, 11, 12);
        end

        send_mail(1'b0, 1'b0, 0, 0, 0, 0);
        
        for (int i = 0; i < 10; i++) begin
            send_mail(1'b1, 1'b0, 0, 0, i, 11);
        end

    endtask

    task T_001();

        send_mail(1'b0, 1'b0, 0, 0, 0, 0);

    endtask

    task T_002();

        send_mail(1'b1, 1'b0, 0, 0, 0, 1);
        send_mail(1'b1, 1'b1, 2, 16'hC1A0, 0, 1);
        send_mail(1'b1, 1'b1, 3, 16'hC1A1, 0, 1);
        send_mail(1'b1, 1'b0, 0, 0, 2, 3);

    endtask

    task T_003();

        send_mail(1'b1, 1'b0, 4, 0, 4, 4);
        send_mail(1'b1, 1'b0, 4, 0, 4, 5);

    endtask

    task T_004();

        send_mail(1'b1, 1'b0, 4, 16'hAAAA, 4, 5);

    endtask

    task T_005();

        send_mail(1'b1, 1'b1, 5, 16'hAAAA, 5, 5);

    endtask

    task T_006();

        send_mail(1'b1, 1'b1, 4, 16'hAAAA, 4, 5);

    endtask

    task T_007();

        send_mail(1'b1, 1'b1, 5, 16'hAAAA, 5, 5);

    endtask

    task execute_directed_tests();

        T_000();
        T_001();
        T_002();
        T_003();
        T_004();
        T_005();
        T_006();
        T_007();

    endtask

endclass

class regfile_driver;

    virtual interface regfile_interface regfile_If;
    mailbox #(regfile_mail) gen_drv_mbx;

    function new(virtual interface regfile_interface regfile_If,
                 mailbox #(regfile_mail) gen_drv_mbx);
        this.regfile_If = regfile_If;
        this.gen_drv_mbx = gen_drv_mbx;
    endfunction

    task init_dut();
    
        regfile_If.cb.rst_n    <= 1'b0;
        regfile_If.cb.wr_en    <= 1'b0;
        regfile_If.cb.wr_addr  <= 0;
        regfile_If.cb.wr_data  <= 0;
        regfile_If.cb.rd_addr1 <= 0;
        regfile_If.cb.rd_addr2 <= 1;

        repeat(2) @(posedge regfile_If.clk);
        
        regfile_If.cb.rst_n    <= 1'b1;

        @(posedge regfile_If.clk);

    endtask

    task run();
        regfile_mail mail;
        
        forever begin

            gen_drv_mbx.get(mail); 
            
            regfile_If.cb.rst_n    <= mail.rst_n;
            regfile_If.cb.wr_en    <= mail.wr_en;
            regfile_If.cb.wr_addr  <= mail.wr_addr;
            regfile_If.cb.wr_data  <= mail.wr_data;
            regfile_If.cb.rd_addr1 <= mail.rd_addr1;
            regfile_If.cb.rd_addr2 <= mail.rd_addr2;

            @(posedge regfile_If.clk);
            
        end

    endtask

endclass

class regfile_monitor;

    virtual interface regfile_interface regfile_If;

    mailbox #(regfile_mail) mon_scb_mbx;

    int verbosity;

    function new(virtual interface regfile_interface regfile_If,
                 mailbox #(regfile_mail) mon_scb_mbx);
        this.regfile_If = regfile_If;
        this.mon_scb_mbx = mon_scb_mbx;

        if (!$value$plusargs("VERBOSITY=%d", verbosity)) verbosity = 0;
    endfunction

    task run();
    
        regfile_mail mail;

        forever begin
            @(posedge regfile_If.clk);

            mail = new();

            mail.rst_n      = regfile_If.cb.rst_n;
            mail.wr_en      = regfile_If.cb.wr_en;
            mail.wr_addr    = regfile_If.cb.wr_addr;
            mail.wr_data    = regfile_If.cb.wr_data;
            mail.rd_addr1   = regfile_If.cb.rd_addr1;
            mail.rd_addr2   = regfile_If.cb.rd_addr2;
            mail.rd_data1   = regfile_If.cb.rd_data1;
            mail.rd_data2   = regfile_If.cb.rd_data2;
            mail.err        = regfile_If.cb.err;
            
            mon_scb_mbx.put(mail);

            if (verbosity == 2) begin
                $display("Time: %8t | rst: %b | en: %b | wr_addr: %2d | wr_data: %4h | err: %b | rd_addr1: %2d | rd_addr2: %2d | rd_data1: %4h | rd_data2: %4h |",
                    $time, regfile_If.rst_n, regfile_If.cb.wr_en, regfile_If.cb.wr_addr, regfile_If.cb.wr_data, regfile_If.cb.err, regfile_If.cb.rd_addr1, regfile_If.cb.rd_addr2, regfile_If.cb.rd_data1, regfile_If.cb.rd_data2);
            end
        end 

    endtask

endclass

module regfile_checker (
    input logic clk,
    input logic rst_n,
    input logic wr_en,
    input logic err,
    input logic [ADDR_WIDTH - 1 : 0] wr_addr,
    input logic [ADDR_WIDTH - 1 : 0] rd_addr1,
    input logic [ADDR_WIDTH - 1 : 0] rd_addr2
);

    int success_count[CHK_CHECKS] = '{default:0};
    int error_count  [CHK_CHECKS] = '{default:0};
    
    int verbosity;
    initial if (!$value$plusargs("VERBOSITY=%d", verbosity)) verbosity = 0;

    logic is_illegal;
    assign is_illegal = (rd_addr1 == rd_addr2) || 
                        (wr_en && (wr_addr == rd_addr1 || wr_addr == rd_addr2));

    property p_err_forward;
        @(posedge clk) disable iff (!rst_n)
        is_illegal |=> (err === 1'b1);
    endproperty

    property p_err_backward;
        @(posedge clk) disable iff (!rst_n)
        (err === 1'b1) |-> $past(is_illegal);
    endproperty

    assert property (p_err_forward) else begin
        if (verbosity > 0) $error("err signal failed: not going high");
        error_count[0] += 1;
    end

    cover property (p_err_forward) begin
        success_count[0] += 1;
    end

    assert property (p_err_backward) else begin
        if (verbosity > 0) $error("err signal failed: high with no reason");
        error_count[1] += 1;
    end

    cover property (p_err_backward) begin
        success_count[1] += 1;
    end

    function automatic void print_error_count();
        int success_count_total = 0, error_count_total = 0;

        for (int i = 0; i < CHK_CHECKS; i++) begin
            success_count_total += success_count[i];
            error_count_total   += error_count[i];
        end

        $display("*************************************");
        $display("* checker                           *");
        $display("* success / errors: %6d / %6d *", success_count_total, error_count_total);
        $display("*************************************");
        $display("* err not high:     %6d / %6d *", success_count[0], error_count[0]);
        $display("*     err high:     %6d / %6d *", success_count[1], error_count[1]);
        $display("*************************************");
    endfunction

endmodule

class regfile_scoreboard;

    mailbox #(regfile_mail) mon_scb_mbx;
    regfile_mail mail;

    logic [DATA_WIDTH - 1 : 0] golden_model_data [NUM_REG] = '{default : 0};

    int success_count[SCB_CHECKS] = '{default:0};
    int error_count  [SCB_CHECKS] = '{default:0};

    int verbosity;

    function new(mailbox #(regfile_mail) mon_scb_mbx);
        this.mon_scb_mbx = mon_scb_mbx;
        if (!$value$plusargs("VERBOSITY=%d", verbosity)) verbosity = 0;
    endfunction

    function void reset();
        for (int i = 0; i < NUM_REG; i++) begin
            golden_model_data[i] = '0;
        end
    endfunction

    function automatic void print_error_count();

        int success_legal_read = success_count[0] + success_count[1];
        int error_legal_read   = error_count[0]   + error_count[1];

        int success_illegal_read = success_count[2] + success_count[3];
        int error_illegal_read   = error_count[2]   + error_count[3];
    
        int success_count_total = 0, error_count_total = 0;

        for (int i = 0; i < SCB_CHECKS; i++) begin
            success_count_total += success_count[i];
            error_count_total   += error_count[i];
        end

        $display("*************************************");
        $display("* scoreboard                        *");
        $display("* success / errors: %6d / %6d *", success_count_total, error_count_total);
        $display("*************************************");
        $display("* legal read tot:   %6d / %6d *", success_legal_read, error_legal_read);
        $display("*   legal read 1:   %6d / %6d *", success_count[0], error_count[0]);
        $display("*   legal read 2:   %6d / %6d *", success_count[1], error_count[1]);
        $display("*************************************");
        $display("* illegal read tot: %6d / %6d *", success_illegal_read, error_illegal_read);
        $display("* illegal read 1:   %6d / %6d *", success_count[2], error_count[2]);
        $display("* illegal read 2:   %6d / %6d *", success_count[3], error_count[3]);
        $display("*************************************");

    endfunction

    task check_legal_rd();

        // check read data 1
        assert(golden_model_data[mail.rd_addr1] == mail.rd_data1) begin
            success_count[0] += 1;
        end else begin
            if (verbosity > 0) $error("Read 1 failed: %0h != %0h", mail.rd_data1, golden_model_data[mail.rd_addr1]);
            error_count[0] += 1;
        end

        // check read data 2
        assert(golden_model_data[mail.rd_addr2] == mail.rd_data2) begin
            success_count[1] += 1;
        end else begin
            if (verbosity > 0) $error("Read 2 failed: %0h != %0h", mail.rd_data2, golden_model_data[mail.rd_addr2]);
            error_count[1] += 1;
        end

    endtask

    task check_illegal_rd();

        // check read data 1
        assert (mail.rd_data1 === 16'bx) begin
            success_count[2] += 1;
        end else begin
            if (verbosity > 0) $error("Read 1 failed: %0h != x", mail.rd_data1);
            error_count[2] += 1;
        end

        // check read data 2
        assert (mail.rd_data2 === 16'bx) begin
            success_count[3] += 1;
        end else begin
            if (verbosity > 0) $error("Read 2 failed: %0h != x", mail.rd_data2);
            error_count[3] += 1;
        end

    endtask

    task check_rd();

        if (mail.is_illegal())
            check_illegal_rd();
        else
            check_legal_rd();

    endtask

    task run();

        forever begin

            mon_scb_mbx.get(mail);

            check_rd();

            // update golden model if legal write
            if (!mail.is_illegal() && mail.wr_en) golden_model_data[mail.wr_addr] = mail.wr_data;
            
            // reset scoreboard if reset low
            if (!mail.rst_n) reset();

        end

    endtask

endclass

module tb_regfile;

    logic clk;
    initial clk = 0;
    always #5 clk = ~clk;

    regfile_interface regfile_If(clk);

    mailbox #(regfile_mail) gen_drv_mbx;
    mailbox #(regfile_mail) mon_scb_mbx;

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

    regfile_checker property_checker (
        .clk      (clk),
        .rst_n    (regfile_If.rst_n),
        .wr_en    (regfile_If.wr_en),
        .err      (regfile_If.err),
        .wr_addr  (regfile_If.wr_addr),
        .rd_addr1 (regfile_If.rd_addr1),
        .rd_addr2 (regfile_If.rd_addr2)
    );

    initial begin

        gen_drv_mbx = new(10);
        mon_scb_mbx = new(); // unbounded

        gen = new(gen_drv_mbx, NUM_RANDOMIZED_TESTS);
        drv = new(regfile_If, gen_drv_mbx);
        mon = new(regfile_If, mon_scb_mbx);
        scb = new(mon_scb_mbx);

        drv.init_dut();

        fork
            drv.run();
            mon.run();
            scb.run();
        join_none

        gen.execute_directed_tests();
        gen.run();

        repeat(5) @(posedge clk);

        print_test_config();
        scb.print_error_count();
        property_checker.print_error_count();

        $finish();
    end

    // initial begin
    //     $dumpfile("waves.vcd"); 
    //     $dumpvars(0, tb_regfile);  
    // end

endmodule
