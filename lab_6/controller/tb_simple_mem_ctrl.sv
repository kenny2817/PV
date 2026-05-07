`timescale 1ns/1ps

module tb_simple_mem_ctrl;

    // Parameters must match DUT
    parameter ADDR_WIDTH = 8;
    parameter DATA_WIDTH = 32;
    localparam MEM_SIZE_WORDS = (1 << ADDR_WIDTH);

    // Clock & Reset
    logic clk;
    logic rst_n;

    // Master 0 (CPU)
    logic [ADDR_WIDTH-1:0] addr0;
    logic [DATA_WIDTH-1:0] wdata0;
    logic [DATA_WIDTH-1:0] rdata0;
    logic we0;
    logic req0;
    wire gnt0;

    // Master 1 (DMA)
    logic [ADDR_WIDTH-1:0] addr1;
    logic [DATA_WIDTH-1:0] wdata1;
    logic [DATA_WIDTH-1:0] rdata1;
    logic we1;
    logic req1;
    wire gnt1;

    // Instantiate DUT
    simple_mem_ctrl #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (.*);

    // Transaction definition (combined for both masters)
    typedef struct packed {
        bit use_m0; // whether master0 participates in this transaction
        bit is_write0;
        logic [ADDR_WIDTH-1:0] addr0;
        logic [DATA_WIDTH-1:0] data0;

        bit use_m1; // whether master1 participates in this transaction
        bit is_write1;
        logic [ADDR_WIDTH-1:0] addr1;
        logic [DATA_WIDTH-1:0] data1;

        int delay_cycles; // cycles to wait before issuing
        bit is_end; // special value to indicate end-of-tests
    } trx_t;

    // Mailbox for sending combined transactions from generator -> single driver
    mailbox trx_mb;
    // Mailbox for monitor->checker communication (uses same trx_t)
    mailbox evt_mb;

    // Minimal counters for checking
    int total_tests = 0;  // total read checks performed
    int failed_tests = 0; // failed read checks

    // Driver end-of-tests flag
    bit driver_done = 0;
    // Checker completion flag
    bit checker_done = 0;

    // Clock gen
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz
    end

    // Reset
    initial begin
        rst_n = 0;
        #20;
        rst_n = 1;
    end

    // Simple helper to wait for the generator to finish placing transactions
    semaphore gen_done_sem = new(0);
    task automatic wait_for_generation_done();
        gen_done_sem.get();
        $display("%0t: [GEN] Finished: driver/monitor will drain mailbox before the end.", $time);
    endtask

    // ---------------------------
    // Generator: sends a set of transactions
    // ---------------------------
    task automatic tb_generator();
        // Design: Create deterministic and random tests, including contention scenarios
        trx_t trx;

        // Deterministic single master writes + reads (only master0 participates)
        for (int a = 0; a < 8; a++) begin
            trx = '{ use_m0: 1, is_write0: 1, addr0: a, data0: (a * 16) + 100,
                     use_m1: 0, is_write1: 0, addr1: '0, data1: '0,
                     delay_cycles: 1 + $urandom_range(0,2), is_end: 0 };
            trx_mb.put(trx);

            // Now read it back
            trx = '{ use_m0: 1, is_write0: 0, addr0: a, data0: '0,
                     use_m1: 0, is_write1: 0, addr1: '0, data1: '0,
                     delay_cycles: 1 + $urandom_range(0,2), is_end: 0 };
            trx_mb.put(trx);
        end

        // DMA writes/reads (master 1)
        for (int a = 8; a < 16; a++) begin
            trx = '{ use_m0: 0, is_write0: 0, addr0: '0, data0: '0,
                     use_m1: 1, is_write1: 1, addr1: a, data1: (a * 16) + 200,
                     delay_cycles: 1 + $urandom_range(0,2), is_end: 0 };
            trx_mb.put(trx);

            // Now read it back
            trx = '{ use_m0: 0, is_write0: 0, addr0: '0, data0: '0,
                     use_m1: 1, is_write1: 0, addr1: a, data1: '0,
                     delay_cycles: 1 + $urandom_range(0,2), is_end: 0 };
            trx_mb.put(trx);
        end

        // Contention tests: both masters request the same time
        // We'll pack two transactions that should be started simultaneously
        // We'll achieve this by putting two trx with 0 delay and letting the driver start them without staggering.
        // Master 0 should win arbitration over Master 1.
        for (int a = 16; a < 18; a++) begin
            // Simultaneous write by both masters (contention)
            trx = '{ use_m0: 1, is_write0: 1, addr0: a, data0: (a * 16) + 300,
                     use_m1: 1, is_write1: 1, addr1: a, data1: (a * 16) + 400,
                     delay_cycles: 0, is_end: 0 };
            trx_mb.put(trx);

            // Next cycles read back (both masters reading)
            trx = '{ use_m0: 1, is_write0: 0, addr0: a, data0: '0,
                     use_m1: 1, is_write1: 0, addr1: a, data1: '0,
                     delay_cycles: 1, is_end: 0 };
            trx_mb.put(trx);
        end

        // Randomized mixed operations
        for (int n = 0; n < 30; n++) begin
            int pick = $urandom_range(0,2); // 0 -> m0, 1 -> m1, 2 -> both
            if (pick == 0) begin
                trx = '{ use_m0: 1, is_write0: ($urandom_range(0,1) == 1), addr0: $urandom_range(0, MEM_SIZE_WORDS-1), data0: $urandom,
                         use_m1: 0, is_write1: 0, addr1: '0, data1: '0,
                         delay_cycles: $urandom_range(0,2), is_end: 0 };
            end else if (pick == 1) begin
                trx = '{ use_m0: 0, is_write0: 0, addr0: '0, data0: '0,
                         use_m1: 1, is_write1: ($urandom_range(0,1) == 1), addr1: $urandom_range(0, MEM_SIZE_WORDS-1), data1: $urandom,
                         delay_cycles: $urandom_range(0,2), is_end: 0 };
            end else begin
                trx = '{ use_m0: 1, is_write0: ($urandom_range(0,1) == 1), addr0: $urandom_range(0, MEM_SIZE_WORDS-1), data0: $urandom,
                         use_m1: 1, is_write1: ($urandom_range(0,1) == 1), addr1: $urandom_range(0, MEM_SIZE_WORDS-1), data1: $urandom,
                         delay_cycles: $urandom_range(0,2), is_end: 0 };
            end
            trx_mb.put(trx);
        end

        // Send an end-of-tests transaction so the driver exits when it's processed
        trx = '{default: '0};
        trx.is_end = 1;
        trx_mb.put(trx);

        // Signal generation done
        gen_done_sem.put(1);
        $display("%0t: [GEN] Done placing transactions", $time);
    endtask

    // ---------------------------
    // Driver: reads trx from mailbox and applies signals
    // ---------------------------
    // Combined single driver for both masters (asserts both ports if requested)
    task automatic tb_driver();
        trx_t trx;
        forever begin
            trx_mb.get(trx);

            // If this is our end-of-tests, signal and exit
            if (trx.is_end) begin
                driver_done = 1;
                return;
            end

            if (trx.delay_cycles > 0) begin
                for (int d = 0; d < trx.delay_cycles; d++) @(posedge clk);
            end

            // Assert both masters' reqs on the same negedge if requested
            @(negedge clk);
            if (trx.use_m0) begin
                addr0 = trx.addr0;
                wdata0 = trx.data0;
                we0 = trx.is_write0;
                req0 = 1;
            end
            if (trx.use_m1) begin
                addr1 = trx.addr1;
                wdata1 = trx.data1;
                we1 = trx.is_write1;
                req1 = 1;
            end

            // Log when both are asserted (concurrent)
            if (trx.use_m0 && trx.use_m1) begin
                $display("%0t: [DRV] Asserting both req0 and req1 (addr0=%0d addr1=%0d we0=%b we1=%b)", $time, trx.addr0, trx.addr1, trx.is_write0, trx.is_write1);
            end
            else if (trx.use_m0) begin
                $display("%0t: [DRV] Asserting req0 master0 addr=%0d we=%b", $time, trx.addr0, trx.is_write0);
            end else if (trx.use_m1) begin
                $display("%0t: [DRV] Asserting req1 master1 addr=%0d we=%b", $time, trx.addr1, trx.is_write1);
            end

            // Capture cycle
            @(posedge clk);

            // Release both on the next negedge
            @(negedge clk);
            if (trx.use_m0) begin
                req0 = 0;
                we0 = 0;
                addr0 = '0;
                wdata0 = '0;
            end
            if (trx.use_m1) begin
                req1 = 0;
                we1 = 0;
                addr1 = '0;
                wdata1 = '0;
            end

            // After issuing the transaction, let it settle a bit
            repeat (1) @(posedge clk);
        end
    endtask

    // Checker task (consumes trx_t events from monitor, maintains golden model)
    task automatic tb_checker();
        // Testbench internal reference memory
        logic [DATA_WIDTH-1:0] ref_mem[MEM_SIZE_WORDS];
        trx_t ev;

        // Initialize golden memory
        for (int i = 0; i < MEM_SIZE_WORDS; i++) ref_mem[i] = '0;
        checker_done = 0;

        // Process events from monitor
        forever begin
            evt_mb.get(ev);
            if (ev.is_end) begin
                checker_done = 1;
                $display("%0t: [CHK] Received EOT, exiting", $time);
                return;
            end
            // Process master0
            if (ev.use_m0) begin
                if (ev.is_write0) begin
                    ref_mem[ev.addr0] = ev.data0;
                    $display("%0t: [CHK] WRITE MASTER0 addr=%0d data=0x%0h", $time, ev.addr0, ev.data0);
                end else begin
                    total_tests++;
                    if (ev.data0 !== ref_mem[ev.addr0]) begin
                        failed_tests++;
                        $display("%0t: [CHK] ERROR: READ MASTER0 addr=%0d expected=0x%0h observed=0x%0h", $time, ev.addr0, ref_mem[ev.addr0], ev.data0);
                    end else begin
                        $display("%0t: [CHK] READ MASTER0 addr=%0d value OK 0x%0h", $time, ev.addr0, ev.data0);
                    end
                end
            end
            // Process master1
            if (ev.use_m1) begin
                if (ev.is_write1) begin
                    ref_mem[ev.addr1] = ev.data1;
                    $display("%0t: [CHK] WRITE MASTER1 addr=%0d data=0x%0h", $time, ev.addr1, ev.data1);
                end else begin
                    total_tests++;
                    if (ev.data1 !== ref_mem[ev.addr1]) begin
                        failed_tests++;
                        $display("%0t: [CHK] ERROR: READ MASTER1 addr=%0d expected=0x%0h observed=0x%0h", $time, ev.addr1, ref_mem[ev.addr1], ev.data1);
                    end else begin
                        $display("%0t: [CHK] READ MASTER1 addr=%0d value OK 0x%0h", $time, ev.addr1, ev.data1);
                    end
                end
            end
        end
    endtask

    // ---------------------------
    // Monitor: samples DUT signals and updates checklist
    // ---------------------------
    task automatic tb_monitor();

        // We will sample signals at posedge for writes, and on stable time for reads
        forever begin
            trx_t ev_pkt;
            bit any_write;
            bit any_read;

            @(posedge clk);
            if (!rst_n) continue; // ignore during reset

            // Detect simultaneous request assertions (concurrency)
            if (req0 && req1) begin
                $display("%0t: [MON] Concurrent requests detected: req0 (addr=%0d we=%b) req1 (addr=%0d we=%b)", $time, addr0, we0, addr1, we1);
            end

            // Write detection
            ev_pkt = '{default: '0};
            any_write = 0;
            if (gnt0 && we0) begin
                ev_pkt.use_m0 = 1;
                ev_pkt.is_write0 = 1;
                ev_pkt.addr0 = addr0;
                ev_pkt.data0 = wdata0;
                any_write = 1;
            end
            if (gnt1 && we1) begin
                ev_pkt.use_m1 = 1;
                ev_pkt.is_write1 = 1;
                ev_pkt.addr1 = addr1;
                ev_pkt.data1 = wdata1;
                any_write = 1;
            end
            if (any_write) begin
                evt_mb.put(ev_pkt);
                $display("%0t: [MON] WRITE event enqueued (use_m0=%b use_m1=%b)", $time, ev_pkt.use_m0, ev_pkt.use_m1);
            end

            // Read detection
            ev_pkt = '{default: '0};
            any_read = 0;
            if (gnt0 && !we0) begin
                ev_pkt.use_m0 = 1;
                ev_pkt.is_write0 = 0;
                ev_pkt.addr0 = addr0;
                ev_pkt.data0 = rdata0;
                any_read = 1;
            end
            if (gnt1 && !we1) begin
                ev_pkt.use_m1 = 1;
                ev_pkt.is_write1 = 0;
                ev_pkt.addr1 = addr1;
                ev_pkt.data1 = rdata1;
                any_read = 1;
            end
            if (any_read) begin
                evt_mb.put(ev_pkt);
                $display("%0t: [MON] READ event enqueued (use_m0=%b use_m1=%b)", $time, ev_pkt.use_m0, ev_pkt.use_m1);
            end
        end
    endtask

    // ------------------------------------------------------------------
    // Main: starts generator/driver/monitor, waits for completion, prints summary
    // ------------------------------------------------------------------
    initial begin
    // Initialize DUT inputs
    addr0  = '0;
    wdata0 = '0;
    we0    = 0;
    req0   = 0;

    addr1  = '0;
    wdata1 = '0;
    we1    = 0;
    req1   = 0;

    trx_mb = new();
    evt_mb = new();

    $display("%0t: [TSB] Starting TB: %m", $time);

    // Start active processes (do not block)
    fork
        tb_generator();
        tb_driver();
        tb_monitor();
        tb_checker();
    join_none

    // Wait for generation and both checker and driver to finish
    wait_for_generation_done();
    wait (driver_done == 1);

    // Now that the driver is done and no more requests will be generated, send EOT to checker
    begin
        trx_t ev_eot;
        ev_eot = '{default: '0};
        ev_eot.is_end = 1;
        evt_mb.put(ev_eot);
    end
    wait (checker_done == 1);

    // Small settle for monitor
    #10;
    $display("%0t: [TSB] TB finished.", $time);
    $display("%0t: [TSB] Read checks: total=%0d failed=%0d", $time, total_tests, failed_tests);
    $finish;
end

endmodule
