`timescale 1ns/1ps

`ifndef DUT_NAME
    `define DUT_NAME regfile_v0
`endif

package constants;
    localparam int NUM_REG = 32;
    localparam int DATA_WIDTH = 16;
    localparam int ADDR_WIDTH = $clog2(NUM_REG);
    localparam int NUM_DIRECTED_TESTS = 8;
    localparam int NUM_RANDOMIZED_TESTS = 100;
    localparam int SEED = 1234;
    localparam int SCB_CHECKS = 3;
endpackage

import constants::*;

interface regfile_if (input logic clk);

    logic                      rst_n, wr_en, err;
    logic [ADDR_WIDTH - 1 : 0] wr_addr, rd_addr1, rd_addr2;
    logic [DATA_WIDTH - 1 : 0] wr_data, rd_data1, rd_data2;

    bit is_illegal;

    clocking cb @(posedge clk);

        default input #0s output #0s; 

        input  rd_data1, rd_data2, err;

        output rst_n, wr_en, wr_addr, wr_data, rd_addr1, rd_addr2;

    endclocking

endinterface

module regfile_assertions (
    input logic clk,
    input logic rst_n,
    input logic wr_en,
    input logic err,
    input logic [ADDR_WIDTH - 1 : 0] wr_addr,
    input logic [ADDR_WIDTH - 1 : 0] rd_addr1,
    input logic [ADDR_WIDTH - 1 : 0] rd_addr2
);

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

    assert property (p_err_forward)  else $error("FAIL: err signal not going high");
    assert property (p_err_backward) else $error("FAIL: err signal high with no reason");

endmodule

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

    // 1. Balance Writes and Reads
    // Ensures the DUT isn't starved of either operation.
    constraint c_wr_en {
        wr_en dist { 1'b1 := 50, 1'b0 := 50 }; // 50% chance of write, 50% chance of read-only
    }

    // 2. Data Corner Cases
    // Plain random data is good, but injecting specific patterns catches bit-level wiring bugs.
    constraint c_data_corners {
        wr_data dist {
            16'h0000 := 1,     // All zeros
            16'hFFFF := 1,     // All ones
            16'hAAAA := 1,     // Alternating 1010
            16'h5555 := 1,     // Alternating 0101
            [0:16'hFFFF] :/ 16 // Normal random data the rest of the time
        };
    }

    // 3. Boost Illegal Address Collisions (The 'err' flag scenarios)
    // The spec specifically flags rd_addr1 == rd_addr2 and Write-to-Read overlaps as illegal.
    constraint c_addr_collisions {
        // Boost the chance of an illegal Read/Read collision to ~20%
        rd_addr1 dist { rd_addr2 := 2, [0:31] :/ 8 };
        
        // Boost the chance of an illegal Write/Read collision to ~20%
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

    task send_mail(
        bit rst_n,
        bit wr_en,
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

    virtual interface regfile_if regfile_If;
    mailbox #(regfile_mail) gen_drv_mbx;

    function new(virtual interface regfile_if regfile_If,
                 mailbox #(regfile_mail) gen_drv_mbx);
        this.regfile_If = regfile_If;
        this.gen_drv_mbx = gen_drv_mbx;
    endfunction

    task init_dut();
    
        regfile_If.cb.rst_n    <= 1'b1;
        regfile_If.cb.wr_en    <= 1'b0;
        regfile_If.cb.wr_addr  <= 0;
        regfile_If.cb.wr_data  <= 0;
        regfile_If.cb.rd_addr1 <= 0;
        regfile_If.cb.rd_addr2 <= 1;
        regfile_If.cb.rst_n    <= 1'b0;

        @(posedge regfile_If.clk);
        
        regfile_If.cb.rst_n    <= 1'b1;

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

    virtual interface regfile_if regfile_If;

    mailbox #(regfile_mail) mon_scb_mbx;

    function new(virtual interface regfile_if regfile_If,
                 mailbox #(regfile_mail) mon_scb_mbx);
        this.regfile_If = regfile_If;
        this.mon_scb_mbx = mon_scb_mbx;
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

            $display("Time: %8t | rst: %b | en: %b | wr_addr: %2d | wr_data: %4h | err: %b | rd_addr1: %2d | rd_addr2: %2d | rd_data1: %4h | rd_data2: %4h |",
                $time, regfile_If.rst_n, regfile_If.cb.wr_en, regfile_If.cb.wr_addr, regfile_If.cb.wr_data, regfile_If.cb.err, regfile_If.cb.rd_addr1, regfile_If.cb.rd_addr2, regfile_If.cb.rd_data1, regfile_If.cb.rd_data2);
        end 

    endtask

endclass

class regfile_scoreboard;

    mailbox #(regfile_mail) mon_scb_mbx;
    regfile_mail mail;

    logic [DATA_WIDTH - 1 : 0] golden_model_data [NUM_REG] = '{default : 0};

    int success_count[SCB_CHECKS] = '{default:0};
    int error_count[SCB_CHECKS] = '{default:0};

    function void reset();
        for (int i = 0; i < NUM_REG; i++) begin
            golden_model_data[i] = '0;
        end
    endfunction

    function new(mailbox #(regfile_mail) mon_scb_mbx);
        this.mon_scb_mbx = mon_scb_mbx;
    endfunction

    function automatic void print_error_count();
    
        int success_count_total = 0, error_count_total = 0;

        for (int i = 0; i < SCB_CHECKS; i++) begin
            success_count_total += success_count[i];
            error_count_total   += error_count[i];
        end

        $display("*********************************");
        $display("* Randomized tests:      %5d *", NUM_RANDOMIZED_TESTS);
        $display("*********************************");
        $display("* success / errors: %4d / %4d *", success_count_total, error_count_total);
        $display("*********************************");
        $display("* illegal read:     %4d / %4d *", success_count[0], error_count[0]);
        $display("* legal read 1:     %4d / %4d *", success_count[1], error_count[1]);
        $display("* legal read 2:     %4d / %4d *", success_count[2], error_count[2]);
        $display("*********************************");

    endfunction

    task check_illegal_rd();

            // check read data 1 and 2
            assert (mail.rd_data1 === 16'bx && mail.rd_data2 === 16'bx) begin
                success_count[0] = success_count[0] + 1;
            end else begin
                $error("Read failed: %0h != x | %0h != x", 
                        mail.rd_data1, mail.rd_data2);
                error_count[0] = error_count[0] + 1;
            end

    endtask

    task check_legal_rd();

        // check read data 1
        assert(golden_model_data[mail.rd_addr1] == mail.rd_data1 && 
                golden_model_data[mail.rd_addr2] == mail.rd_data2) begin
            success_count[1] = success_count[1] + 1;
        end else begin
            $error("Read failed: %0h != %0h | %0h != %0h",
                    golden_model_data[mail.rd_addr1],
                    mail.rd_data1,
                    golden_model_data[mail.rd_addr2],
                    mail.rd_data2);
            error_count[1] = error_count[1] + 1;
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

    regfile_if regfile_If(clk);

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

    bind dut regfile_assertions property_checker (
        .clk      (clk),
        .rst_n    (rst_n),
        .wr_en    (wr_en),
        .err      (err),
        .wr_addr  (wr_addr),
        .rd_addr1 (rd_addr1),
        .rd_addr2 (rd_addr2)
    );

    initial begin

        gen_drv_mbx = new(1);
        mon_scb_mbx = new(); // unbounded

        gen = new(gen_drv_mbx, NUM_RANDOMIZED_TESTS, SEED);
        drv = new(regfile_If, gen_drv_mbx);
        mon = new(regfile_If, mon_scb_mbx);
        scb = new(mon_scb_mbx);

        drv.init_dut();

        fork
            drv.run();
            mon.run();
            scb.run();
        join_none

        gen.execute_directed_tests(); // directed tests checked by scoreboard

        // randomized tests
        gen.run();

        repeat(5) @(posedge clk);

        scb.print_error_count();
        $finish();
    end

endmodule
