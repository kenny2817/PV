`timescale 1ns/1ps
`include "uvm_macros.svh" 

package ctrl_const_pkg;
    localparam int ADDR_WIDTH = 8;
    localparam int MEM_SIZE_WORDS = 1 << ADDR_WIDTH;
    localparam int DATA_WIDTH = 32;
endpackage

import ctrl_const_pkg::*;

interface ctrl_interface (
    input logic clk,
    input logic rst_n
);
    
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] wdata;
    logic [DATA_WIDTH-1:0] rdata;
    logic                  we;
    logic                  req;
    logic                  gnt;
    
    clocking cb @(posedge clk);
        default input #1step output #0;
        input rdata, gnt;
        inout rst_n, addr, wdata, we, req;
    endclocking

endinterface

package ctrl_pkg; 
    import uvm_pkg::*;
    import ctrl_const_pkg::*;
    
    class ctrl_input_transaction extends uvm_sequence_item;
        `uvm_object_utils(ctrl_input_transaction)
        
        rand bit                    we;
        rand logic [ADDR_WIDTH-1:0] addr;
        rand logic [DATA_WIDTH-1:0] wdata;

        rand int                    delay_cycles;
        
        function new(string name = "ctrl_input_transaction");
            super.new(name);
        endfunction

        function string convert2string();
            return $sformatf(
                "M: [%0s] Addr=%0h Data=%0h Delay=%0d", 
                (we ? "WR" : "RD"), addr, wdata, delay_cycles
            );
        endfunction

    endclass

    class ctrl_output_transaction extends uvm_sequence_item;
        `uvm_object_utils(ctrl_output_transaction)

        logic                  we;
        logic [ADDR_WIDTH-1:0] addr;
        logic [DATA_WIDTH-1:0] rdata;
        logic [DATA_WIDTH-1:0] wdata;

        function new(string name = "ctrl_output_transaction");
            super.new(name);
        endfunction

        function string convert2string();
            return $sformatf(
                "M: [%0s] Addr=%0h Wdata=%0h Rdata=%0h",
                (we ? "WR" : "RD"), addr, wdata, rdata
            );
        endfunction

    endclass

    class ctrl_rst_transaction extends uvm_sequence_item;
        `uvm_object_utils(ctrl_rst_transaction)
        
        function new(string name="ctrl_rst_transaction");
            super.new(name);
        endfunction

    endclass

    class ctrl_driver extends uvm_driver #(ctrl_input_transaction);
        `uvm_component_utils(ctrl_driver)

        virtual ctrl_interface ctrl_if; 

        function new(string name = "ctrl_driver", uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual ctrl_interface)::get(this, "", "vif", ctrl_if)) begin
                `uvm_fatal("DRV", "Interface not found")
            end
        endfunction

        task apply(ctrl_input_transaction trans);
            repeat (trans.delay_cycles) @(posedge ctrl_if.clk); // apply delay
            ctrl_if.cb.req      <= 1'b1;
            ctrl_if.cb.we       <= trans.we;
            ctrl_if.cb.addr     <= trans.addr;
            ctrl_if.cb.wdata    <= trans.wdata;
            while (ctrl_if.cb.gnt !== 1'b1) begin
                @(posedge ctrl_if.clk);
            end 
            ctrl_if.cb.req      <= 1'b0; // release
        endtask

        task run_phase(uvm_phase phase);
            ctrl_input_transaction trans;
            forever begin
                wait(!ctrl_if.rst_n); 
                ctrl_if.cb.req   <= 1'b0;
                wait(ctrl_if.rst_n);
                fork
                    begin
                        forever begin
                            seq_item_port.get_next_item(trans);
                            this.apply(trans);
                            seq_item_port.item_done();
                        end
                    end
                    
                    begin
                        wait(!ctrl_if.rst_n); 
                    end
                join_any 
                disable fork; 
            end
        endtask

    endclass

    class ctrl_monitor extends uvm_monitor;
        `uvm_component_utils(ctrl_monitor)

        virtual ctrl_interface ctrl_if;
        uvm_analysis_port #(ctrl_output_transaction) exit_port;

        function new(string name="ctrl_monitor", uvm_component parent=null);
            super.new(name, parent);
            exit_port = new("exit_port", this);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual ctrl_interface)::get(this, "", "vif", ctrl_if)) begin
                `uvm_fatal("MNT", "Interface not found")
            end
        endfunction
        
        task run_phase(uvm_phase phase);
            ctrl_output_transaction trans;
            forever begin
                @(posedge ctrl_if.clk);
                if (ctrl_if.cb.req && ctrl_if.cb.gnt) begin
                    trans = ctrl_output_transaction::type_id::create("trans");
                    trans.we    = ctrl_if.cb.we;
                    trans.addr  = ctrl_if.cb.addr;
                    trans.rdata = ctrl_if.cb.rdata;
                    trans.wdata = ctrl_if.cb.wdata;
                    exit_port.write(trans);
                    `uvm_info("MNT", trans.convert2string(), UVM_HIGH)
                end
            end
        endtask

    endclass

    class ctrl_rst_monitor extends uvm_monitor;
        `uvm_component_utils(ctrl_rst_monitor)

        virtual ctrl_interface ctrl_if;
        uvm_analysis_port #(ctrl_rst_transaction) exit_port;

        function new(string name="ctrl_rst_monitor", uvm_component parent=null);
            super.new(name, parent);
            exit_port = new("exit_port", this);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual ctrl_interface)::get(this, "", "vif", ctrl_if))
                `uvm_fatal("RST", "Interface not found")
        endfunction

        task run_phase(uvm_phase phase);
            ctrl_rst_transaction trans;
            forever begin
                @(negedge ctrl_if.rst_n); // Wait for the drop
                `uvm_info("RST", "[ON]", UVM_MEDIUM)
                exit_port.write(ctrl_rst_transaction::type_id::create("trans"));
                @(posedge ctrl_if.rst_n);
                `uvm_info("RST", "[OFF]", UVM_MEDIUM)
            end
        endtask
        
    endclass

    class ctrl_sequencer extends uvm_sequencer #(ctrl_input_transaction);
        `uvm_component_utils(ctrl_sequencer)

        function new(string name="ctrl_sequencer", uvm_component parent=null);
            super.new(name, parent);
        endfunction

    endclass

    class ctrl_agent extends uvm_agent;
        `uvm_component_utils(ctrl_agent)

        ctrl_sequencer sqr;
        ctrl_driver   drv;
        ctrl_monitor  mnt;

        function new(string name = "ctrl_agent", uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sqr = ctrl_sequencer::type_id::create("sqr", this);
            drv = ctrl_driver::type_id::create("drv", this);
            mnt = ctrl_monitor::type_id::create("mnt", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            drv.seq_item_port.connect(sqr.seq_item_export);
        endfunction

    endclass

    `uvm_analysis_imp_decl(_trans)
    `uvm_analysis_imp_decl(_rst)

    class ctrl_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(ctrl_scoreboard)

        int expected_trans = 0;
        int success, fail;
        bit [DATA_WIDTH-1:0] mem [MEM_SIZE_WORDS];
        uvm_analysis_imp_trans #(ctrl_output_transaction, ctrl_scoreboard) entry_port_trans;
        uvm_analysis_imp_rst   #(ctrl_rst_transaction,    ctrl_scoreboard) entry_port_rst;

        function new(string name = "ctrl_scoreboard", uvm_component parent = null);
            super.new(name, parent);
            entry_port_trans = new("entry_port_trans", this);
            entry_port_rst   = new("entry_port_rst",  this);
            for (int i = 0; i < MEM_SIZE_WORDS; i++) begin
                mem[i] = '0;
            end
            success = 0;
            fail = 0;
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(int)::get(this, "", "expected_trans", expected_trans)) begin
                `uvm_info("SCB", "No target set. SCB will not hold objections.", UVM_MEDIUM)
            end
        endfunction

        task run_phase(uvm_phase phase);
            if (expected_trans > 0) begin
                phase.raise_objection(this); 
                `uvm_info("SCB", $sformatf("expected: %d", expected_trans), UVM_MEDIUM)
                wait((success + fail) == expected_trans);
                `uvm_info("SCB", "All expected transactions checked! Releasing lock.", UVM_MEDIUM)
                phase.drop_objection(this);
            end
        endtask

        virtual function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("SCB", $sformatf("Test Complete! Succes: %0d, FAil: %0d", success, fail), UVM_NONE)
        endfunction

        function void write_trans(ctrl_output_transaction trans);
            if (trans.we) begin
                mem[trans.addr] <= trans.wdata;
                success += 1;
                `uvm_info("SCB", $sformatf("[WRITE] addr %h data %h", trans.addr, trans.wdata), UVM_HIGH)
            end else if (mem[trans.addr] === trans.rdata) begin
                success += 1;
                `uvm_info("SCB", $sformatf("[READ OK] addr %h | exp %h got %h", trans.addr, mem[trans.addr], trans.rdata), UVM_HIGH)
            end else begin
                fail += 1;
                `uvm_error("SCB", $sformatf("[READ FAIL] exp %h got %h", mem[trans.addr], trans.rdata))
            end
        endfunction

        function void write_rst(ctrl_rst_transaction trans);
            `uvm_info("SCB", "[RST] golden model reset", UVM_HIGH)
            for (int i = 0; i < MEM_SIZE_WORDS; i++) begin
                mem[i] = '0;
            end
        endfunction

    endclass

    class ctrl_cov_controller extends uvm_subscriber #(ctrl_output_transaction);
        `uvm_component_utils(ctrl_cov_controller)

        bit mem_written_tracker [MEM_SIZE_WORDS];

        covergroup ctrl_cov with function sample(
            logic [ADDR_WIDTH-1:0] addr, 
            bit raw
        );
            cp_addr: coverpoint addr {
                option.weight = 0;
            }
            cp_raw:  coverpoint raw { 
                bins hit = {1};
                option.weight = 0;
            }
            cross_raw: cross cp_addr, cp_raw;
        endgroup

        function new(string name="ctrl_cov_controller", uvm_component parent=null);
            super.new(name, parent);
            ctrl_cov = new();
            foreach(mem_written_tracker[i]) begin
                mem_written_tracker[i] = '0;
            end
        endfunction

        virtual function void write(ctrl_output_transaction t);
            ctrl_cov.sample(t.addr, mem_written_tracker[t.addr] && !t.we);
            mem_written_tracker[t.addr] += t.we;
        endfunction

    endclass

    class ctrl_env extends uvm_env;
        `uvm_component_utils(ctrl_env)

        ctrl_agent master0_agent;
        ctrl_agent master1_agent;
        ctrl_rst_monitor mnt_rst;
        ctrl_scoreboard scb;
        ctrl_cov_controller cov;


        function new(string name = "ctrl_env", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            master0_agent = ctrl_agent::type_id::create("master0_agent", this);
            master1_agent = ctrl_agent::type_id::create("master1_agent", this);
            mnt_rst = ctrl_rst_monitor::type_id::create("mnt_rst", this);
            scb = ctrl_scoreboard::type_id::create("scb", this);
            cov = ctrl_cov_controller::type_id::create("cov", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            master0_agent.mnt.exit_port.connect(scb.entry_port_trans);
            master1_agent.mnt.exit_port.connect(scb.entry_port_trans);
            mnt_rst.exit_port.connect(scb.entry_port_rst);
            master0_agent.mnt.exit_port.connect(cov.analysis_export);
            master1_agent.mnt.exit_port.connect(cov.analysis_export);
        endfunction

    endclass

    class ctrl_det_seq extends uvm_sequence #(ctrl_input_transaction);
        `uvm_object_utils(ctrl_det_seq)
        
        int num_trans = 8;
        int min_delay = 0;
        int max_delay = 2;

        function new(string name = "ctrl_det_seq");
            super.new(name);
        endfunction

        task body();
            ctrl_input_transaction trans;
            `uvm_info("SEQ", $sformatf("sequence [DET]: %d transactions, delay [%d:%d]", num_trans, min_delay, max_delay), UVM_MEDIUM)
            for (int i = 0; i < num_trans; i++) begin
                `uvm_do_with(trans, {
                    we == 1; 
                    addr == i; 
                    wdata == (i * 16) + 100; 
                    delay_cycles inside {[min_delay : max_delay]};
                }) // write
                `uvm_do_with(trans, {
                    we == 0; 
                    addr == i; 
                    wdata == 0;
                    delay_cycles inside {[min_delay : max_delay]};
                }) // read
            end
            `uvm_info("SEQ", $sformatf("sequence [DET] done"), UVM_MEDIUM)
        endtask

    endclass

    class ctrl_rnd_seq extends uvm_sequence #(ctrl_input_transaction);
        `uvm_object_utils(ctrl_rnd_seq)

        int num_trans = 8;
        int min_delay = 0;
        int max_delay = 2;

        function new(string name = "ctrl_rnd_seq");
            super.new(name);
        endfunction

        task body();
            ctrl_input_transaction trans;
            `uvm_info("SEQ", $sformatf("sequence [RND]: %d transactions, delay [%d:%d]", num_trans, min_delay, max_delay), UVM_MEDIUM)
            repeat (num_trans) begin
                `uvm_do_with(trans, {
                    delay_cycles inside {[min_delay : max_delay]};
                })
            end
            `uvm_info("SEQ", $sformatf("sequence [RND] done"), UVM_MEDIUM)
        endtask

    endclass

    class ctrl_det_test extends uvm_test;
        `uvm_component_utils(ctrl_det_test)

        ctrl_env env;

        function new(string name = "ctrl_det_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = ctrl_env::type_id::create("env", this);
            uvm_config_db#(int)::set(this, "*scb*", "expected_trans", 2*(8 + 8 + 16)); 
        endfunction

        task run_phase(uvm_phase phase);
            ctrl_det_seq seq0;
            ctrl_det_seq seq1;
            phase.raise_objection(this);
            seq0 = ctrl_det_seq::type_id::create("seq0");
            seq1 = ctrl_det_seq::type_id::create("seq1");
            seq0.num_trans = 8; seq1.num_trans = 8;
            seq0.min_delay = 1; seq1.min_delay = 1;
            seq0.max_delay = 3; seq1.max_delay = 3;
            // master 0 only
            seq0.start(env.master0_agent.sqr); 
            // master 1 only
            seq1.start(env.master1_agent.sqr);
            seq0.max_delay = 1; seq1.max_delay = 1;
            // both masters
            fork
                seq0.start(env.master0_agent.sqr); 
                seq1.start(env.master1_agent.sqr); 
            join
            phase.drop_objection(this);
        endtask

    endclass

    class ctrl_rnd_test extends uvm_test;
        `uvm_component_utils(ctrl_rnd_test)

        ctrl_env env;

        function new(string name = "ctrl_rnd_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = ctrl_env::type_id::create("env", this);
            uvm_config_db#(int)::set(this, "*scb*", "expected_trans", 20 + 20); 
        endfunction

        task run_phase(uvm_phase phase);
            ctrl_rnd_seq seq0;
            ctrl_rnd_seq seq1;
            phase.raise_objection(this);
            seq0 = ctrl_rnd_seq::type_id::create("seq0");
            seq1 = ctrl_rnd_seq::type_id::create("seq1");
            seq0.num_trans = 20; seq1.num_trans = 20;
            seq0.min_delay = 0; seq1.min_delay = 0;
            seq0.max_delay = 2; seq1.max_delay = 2;
            // both masters
            fork
                seq0.start(env.master0_agent.sqr);
                seq1.start(env.master1_agent.sqr);
            join
            phase.drop_objection(this);
        endtask

    endclass
endpackage

import uvm_pkg::*;
import ctrl_pkg::*;

module ctrl_checker (
    input logic clk,
    input logic rst_n,

    input logic req0,
    input logic gnt0,

    input logic req1,
    input logic gnt1
);

    localparam int CHK_CHECKS = 3;
    int success_count[CHK_CHECKS] = '{default:0};
    int error_count  [CHK_CHECKS] = '{default:0};

    property p_req0;
        @(posedge clk) disable iff (!rst_n || $isunknown(req0) || $isunknown(gnt0))
        req0 == gnt0;
    endproperty

    property p_req1;
        @(posedge clk) disable iff (!rst_n || $isunknown(req0) || $isunknown(req1) || $isunknown(gnt1))
        (req1 && !req0) == gnt1;
    endproperty

    property p_no_both_gnt;
        @(posedge clk) disable iff (!rst_n || $isunknown(gnt0) || $isunknown(gnt1))
        !(gnt0 && gnt1)
    endproperty

    assert property (p_req0) begin
        success_count[0] += 1;
    end else begin
        error_count[0] += 1;
        `uvm_error("CHK", "[MASTER PRIORITY] req0 != gnt0")
    end

    assert property (p_req1) begin
        success_count[1] += 1;
    end else begin
        error_count[1] += 1;
        `uvm_error("CHK", "[MASTER PRIORITY] (req1 && !req0) != gnt1")
    end

    assert property (p_no_both_gnt) begin
        success_count[2] += 1;
    end else begin
        error_count[2] += 1;
        `uvm_error("CHK", "[BOTH GNT] gnt0 && gnt1")
    end

endmodule

module ctrl_cov (
    input logic clk,
    input logic rst_n,

    input logic req0,
    input logic req1
);

    c_req_00: cover property (
        @(posedge clk) disable iff (!rst_n) 
        (!req0 && !req1)
    );

    c_req_10: cover property (
        @(posedge clk) disable iff (!rst_n) 
        (req0 && !req1)
    );

    c_req_01: cover property (
        @(posedge clk) disable iff (!rst_n) 
        (!req0 && req1)
    );

    c_req_11: cover property (
        @(posedge clk) disable iff (!rst_n) 
        (req0 && req1)
    );

endmodule

module tb_ctrl;

    logic clk;
    initial clk = 0;
    always #5 clk = ~clk;
    
    logic rst_n;
    initial begin
        rst_n = 0;
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);
    end

    ctrl_interface ctrl_master0_If(clk, rst_n);
    ctrl_interface ctrl_master1_If(clk, rst_n);
    initial uvm_config_db#(virtual ctrl_interface)::set(null, "*master0_agent*", "vif", ctrl_master0_If);
    initial uvm_config_db#(virtual ctrl_interface)::set(null, "*master1_agent*", "vif", ctrl_master1_If);
    initial uvm_config_db#(virtual ctrl_interface)::set(null, "*mnt_rst*", "vif", ctrl_master0_If);
    
    simple_mem_ctrl #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),

        .addr0    (ctrl_master0_If.addr),
        .wdata0   (ctrl_master0_If.wdata),
        .rdata0   (ctrl_master0_If.rdata),
        .we0      (ctrl_master0_If.we),
        .req0     (ctrl_master0_If.req),
        .gnt0     (ctrl_master0_If.gnt),

        .addr1    (ctrl_master1_If.addr),
        .wdata1   (ctrl_master1_If.wdata),
        .rdata1   (ctrl_master1_If.rdata),
        .we1      (ctrl_master1_If.we),
        .req1     (ctrl_master1_If.req),
        .gnt1     (ctrl_master1_If.gnt)
    );

    bind simple_mem_ctrl ctrl_checker check(
        .clk      (clk),
        .rst_n    (rst_n),
        .req0     (req0),
        .gnt0     (gnt0),
        .req1     (req1),
        .gnt1     (gnt1)
    );

    bind simple_mem_ctrl ctrl_cov cov(
        .clk      (clk),
        .rst_n    (rst_n),
        .req0     (req0),
        .req1     (req1)
    );

    initial run_test("ctrl_det_test");

endmodule