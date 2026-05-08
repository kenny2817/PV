`timescale 1ns/1ps
`include "uvm_macros.svh" 

package ctrl_const_pkg;
    localparam int ADDR_WIDTH = 8;
    localparam int DATA_WIDTH = 32;
endpackage

import ctrl_const_pkg::*;

package ctrl_pkg; 
    import uvm_pkg::*;

    interface ctrl_interface (
        input logic clk,
        input logic rst_n
    );
        
        logic [ADDR_WIDTH-1:0] addr;
        logic [DATA_WIDTH-1:0] wdata
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
                (we ? "WR" : "RD"), addr, data, delay_cycles
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

    class ctrl_driver extends uvm_driver #(ctrl_input_transaction);
        `uvm_component_utils(ctrl_driver)

        virtual ctrl_interface ctrl_if; 

        function new(string name = "ctrl_driver", uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual ctrl_interface)::get(this, "", "vif", ctrl_if)) begin
                `uvm_fatal("DRV", "interface not found")
            end
        endfunction

        task apply(ctrl_input_transaction trans);
            repeat (trans.delay_cycles) @(posedge ctrl_if.clk); // apply delay
            ctrl_if.cb.req      <= 1'b1;
            ctrl_if.cb.we       <= trans.we;
            ctrl_if.cb.addr     <= trans.addr;
            ctrl_if.cb.wdata    <= trans.wdata;
            @(posedge ctrl_if.clk);
            wait (ctrl_if.cb.gnt);
            ctrl_if.cb.req      <= 1'b0; // release
        endtask

        task run_phase(uvm_phase phase);
            ctrl_if.cb.req   <= 1'b0; // init
            ctrl_input_transaction trans;
            forever begin
                seq_item_port.get_next_item(trans);
                this.apply(trans);
                seq_item_port.item_done();
            end
        endtask

    endclass

    class ctrl_monitor extends uvm_monitor;
        `uvm_component_utils(ctrl_monitor)

        virtual ctrl_interface ctrl_if;
        uvm_analysis_port #(ctrl_output_transaction) analysis_port;

        function new(string name="ctrl_monitor", uvm_component parent=null);
            super.new(name, parent);
            analysis_port = new("analysis_port", this);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual ctrl_interface)::get(this, "", "vif", ctrl_if)) begin
                `uvm_fatal("MNT", "interface not found")
            end
        endfunction
        
        task run_phase(uvm_phase phase);
            ctrl_input_transaction trans;
            forever begin
                @(posedge ctrl_if.clk);
                if (ctrl_if.cb.req && ctrl_if.cb.gnt) begin
                    trans = ctrl_output_transaction::type_id::create("trans");
                    trans.we    = ctrl_if.cb.we;
                    trans.addr  = ctrl_if.cb.addr;
                    trans.rdata = ctrl_if.cb.rdata;
                    trans.wdata = ctrl_if.cb.wdata;
                    analysis_port.write(trans);
                    `uvm_info("MNT", trans.convert2string(), UVM_HIGH)
                end
            end
        endtask

    endclass

    class ctrl_sequencer extends uvm_sequencer #(ctrl_input_transaction);
        `uvm_component_utils(ctrl_sequencer)
    endclass

    class ctrl_agent extends uvm_agent;
        `uvm_component_utils(ctrl_agent)

        uvm_sequencer sqr;
        ctrl_driver   drv;
        ctrl_monitor  mon;

        function new(string name = "ctrl_agent", uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sqr = uvm_sequencer::type_id::create("sqr", this);
            drv = ctrl_driver::type_id::create("drv", this);
            mon = ctrl_monitor::type_id::create("mon", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            drv.seq_item_port.connect(sqr.seq_item_export);
        endfunction

    endclass

    class ctrl_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(ctrl_scoreboard)

        uvm_analysis_port #(ctrl_output_transaction) analysis_port;

        function new(string name = "ctrl_scoreboard", uvm_component parent = null);
            super.new(name, parent);
            analysis_port = new("analysis_port", this);
        endfunction

        function void write(ctrl_output_transaction trans);
            `uvm_info("SCB", trans.convert2string(), UVM_HIGH)
        endfunction

    endclass

    class ctrl_env extends uvm_env;
        `uvm_component_utils(ctrl_env)

        ctrl_agent master0_agent;
        ctrl_agent master1_agent;
        ctrl_scoreboard scb;

        function new(string name = "ctrl_env", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            master0_agent = ctrl_agent::type_id::create("master0_agent", this); // outing the if
            master1_agent = ctrl_agent::type_id::create("master1_agent", this); // outing the if
            scb = ctrl_scoreboard::type_id::create("scb", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            master0_agent.sqr.connect(scb.sqr);
            master1_agent.sqr.connect(scb.sqr);
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
            `uvm_info("SEQ", $sformatf("sequence [DET]: %d transactions, delay [%d:%d]", num_trans, min_delay, max_delay), UVM_MEDIUM)
            ctrl_input_transaction trans;
            for (int i = 0; i < num_trans; i++) begin
                `uvm_do_with(trans, {
                    we == 1; 
                    addr == i; 
                    wdata == (i * 16) + 100; 
                    delay_cycles inside {[min_delay : max_delay]};
                }) // write
                seq_item_port.put_item(trans);
                `uvm_do_with(trans, {
                    we == 0; 
                    addr == i; 
                    wdata == 0;
                    delay_cycles inside {[min_delay : max_delay]};
                }) // read
                seq_item_port.put_item(trans);
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
            `uvm_info("SEQ", $sformatf("sequence [RND]: %d transactions, delay [%d:%d]", num_trans, min_delay, max_delay), UVM_MEDIUM)
            ctrl_input_transaction trans;
            repeat (num_trans) begin
                `uvm_do_with(trans, {
                    delay_cycles inside {[min_delay : max_delay]};
                })
                seq_item_port.put_item(trans);
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
import controller_pkg::*;// Parameters must match DUTparameterADDR_WIDTH = 8;parameterDATA_WIDTH = 32;...endmodule: tb_uvm_simple_mem_ctrl

module tb_ctrl;

    logic clk, rst_n;

    ctrl_interface ctrl_master0_If(clk, rst_n);
    ctrl_interface ctrl_master1_If(clk, rst_n);

    initial uvm_config_db#(virtual ctrl_interface)::set(null, "*master0_agent*", "vif", ctrl_master0_If);
    initial uvm_config_db#(virtual ctrl_interface)::set(null, "*master1_agent*", "vif", ctrl_master1_If);

    simple_mem_ctrl dut (
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

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        run_test("ctrl_det_test");
        // run_test("ctrl_rnd_test");
    end
endmodule