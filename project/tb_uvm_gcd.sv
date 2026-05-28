
`timescale 1ns/1ps
`include "uvm_macros.svh" 

package gcd_const_pkg;
    localparam int DATA_WIDTH = 32;
endpackage

import gcd_const_pkg::*;

interface gcd_interface (
    input logic clk,
    input logic rst_n
);

    // input interface
    logic                   in_valid;
    logic                   in_ready;
    logic [DATA_WIDTH-1:0]  a_in;
    logic [DATA_WIDTH-1:0]  b_in;

    // output interface
    logic                   out_valid;
    logic                   out_ready;
    logic [DATA_WIDTH-1:0]  gcd_out;
    
    clocking cb @(posedge clk);
        default input #1step output #0;
        input in_ready, out_valid, gcd_out;
        inout in_valid, a_in, b_in, out_ready;
    endclocking

endinterface

package gcd_pkg;

    import uvm_pkg::*;
    import gcd_const_pkg::*;
    
    class gcd_input_transaction extends uvm_sequence_item;
        `uvm_object_utils(gcd_input_transaction)

        bit [DATA_WIDTH -1 : 0] a, b;
        int delay_cycles;

        function new(string name = "gcd_input_transaction");
            super.new(name);
        endfunction

        function string convert2string();
            return $sformatf("[A] %d [B] %d [DELAY] %d", a, b, delay_cycles);
        endfunction

    endclass

    class gcd_input_driver extends uvm_driver #(gcd_input_transaction);
        `uvm_component_utils(gcd_input_driver)

        virtual gcd_interface gcd_if;

        function new(string name = "gcd_input_driver", uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual gcd_interface)::get(this, "", "vif", gcd_if)) begin
                `uvm_fatal("DRV", "Interface not found")
            end
        endfunction

        task apply(gcd_input_transaction trans);
            repeat (trans.delay_cycles) @(posedge gcd_if.clk);
            gcd_if.cb.in_valid  <= 1'b1;
            gcd_if.cb.a_in      <= trans.a;
            gcd_if.cb.b_in      <= trans.b;
            @(posedge gcd_if.clk);
            while (gcd_if.cb.in_ready !== 1'b1) begin
                @(posedge gcd_if.clk);
            end
            gcd_if.cb.in_valid  <= 1'b0;
        endtask

        task run_phase(uvm_phase phase);
            gcd_input_transaction trans;
            forever begin
                wait(!gcd_if.rst_n);
                gcd_if.cb.in_valid <= 1'b0;
                wait(gcd_if.rst_n);
                fork
                    begin
                        forever begin
                            seq_item_port.get_next_item(trans);
                            this.apply(trans);
                            seq_item_port.item_done();
                        end
                    end
                    
                    begin
                        wait(!gcd_if.rst_n);
                    end
                join_any
                disable fork;
            end
        endtask

    endclass

    class gcd_input_monitor extends uvm_monitor;
        `uvm_component_utils(gcd_input_monitor)

        virtual gcd_interface gcd_if;
        uvm_analysis_port #(gcd_input_transaction) exit_port

        function new(string name="gcd_input_monitor", uvm_component parent=null);
            super.new(name, parent);
            exit_port = new("exit_port", this);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual gcd_interface)::get(this, "", "vif", gcd_if)) begin
                `uvm_fatal("MNT", "Interface not found")
            end
        endfunction
        
        task run_phase(uvm_phase phase);
            gcd_input_transaction trans;
            forever begin
                @(posedge gcd_if.clk);
                if (gcd_if.cb.in_ready && gcd_if.cb.in_valid) begin
                    if ($isunknown(gcd_if.cb.a_in) || $isunknown(gcd_if.cb.b_in)) begin
                        `uvm_error("MNT", "(X/Z) value detected")
                    end
                    trans = gcd_input_transaction::type_id::create("trans");
                    trans.a = gcd_if.cb.a_in;
                    trans.b = gcd_if.cb.b_in;
                    exit_port.write(trans);
                    `uvm_info("MNT", trans.convert2string(), UVM_DEBUG)
                end
            end
        endtask

    endclass

    class gcd_input_agent extends uvm_agent;
        `uvm_component_utils(gcd_agent)

        gcd_input_driver  drv;
        gcd_input_monitor mnt;

        function new(string name = "gcd_input_agent", uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            drv = gcd_input_driver::type_id::create("drv", this);
            mnt = gcd_input_monitor::type_id::create("mnt", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            drv.seq_item_export.connect(mnt.exit_port);
        endfunction

    endclass

    class gcd_output_transaction extends uvm_sequence_item;
        `uvm_object_utils(gcd_output_transaction)

        bit [DATA_WIDTH -1 : 0] gcd;
        int delay_cycles;

        function new(string name = "gcd_output_transaction");
            super.new(name);
        endfunction

        function string convert2string();
            return $sformatf("[GCD] %d [DELAY] %d", gcd, delay_cycles);
        endfunction

    endclass

    class gcd_ouput_driver extends uvm_driver #(gcd_output_transaction);
        `uvm_component_utils(gcd_ouput_driver)

        virtual gcd_interface gcd_if;

        function new(string name = "gcd_ouput_driver", uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual gcd_interface)::get(this, "", "vif", gcd_if)) begin
                `uvm_fatal("DRV", "Interface not found")
            end
        endfunction

        task apply(gcd_output_transaction trans);
            while (gcd_if.cb.out_ready !== 1'b1) begin
                @(posedge gcd_if.clk);
            end
            repeat (trans.delay_cycles) @(posedge gcd_if.clk);
            gcd_if.cb.out_valid <= 1'b1;
            @(posedge gcd_if.clk);
            while (gcd_if.cb.out_ready !== 1'b1) begin
                @(posedge gcd_if.clk);
            end
            gcd_if.cb.out_valid <= 1'b0;
        endtask

        task run_phase(uvm_phase phase);
            gcd_output_transaction trans;
            forever begin
                wait(!gcd_if.rst_n);
                gcd_if.cb.out_valid <= 1'b0;
                wait(gcd_if.rst_n);
                fork
                    begin
                        forever begin
                            seq_item_port.get_next_item(trans);
                            this.apply(trans);
                            seq_item_port.item_done();
                        end
                    end
                    
                    begin
                        wait(!gcd_if.rst_n);
                    end
                join_any
                disable fork;
            end
        endtask

    endclass

    class gcd_output_monitor extends uvm_monitor;
        `uvm_component_utils(gcd_output_monitor)

        virtual gcd_interface gcd_if;
        uvm_analysis_port #(gcd_output_transaction) exit_port

        function new(string name="gcd_output_monitor", uvm_component parent=null);
            super.new(name, parent);
            exit_port = new("exit_port", this);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual gcd_interface)::get(this, "", "vif", gcd_if)); begin
                `uvm_fatal("MNT", "Interface not found")
            end
        endfunction
        
        task run_phase(uvm_phase phase);
            gcd_output_transaction trans;
            forever begin
                @(posedge gcd_if.clk);
                if (gcd_if.cb.out_ready && gcd_if.cb.out_ready) begin
                    if ($isunknown(gcd_if.cb.gcd_out)) begin
                        `uvm_error("MNT", "(X/Z) value detected")
                    end
                    trans = gcd_output_transaction::type_id::create("trans");
                    trans.gcd = gcd_if.cb.gcd_out;
                    exit_port.write(trans);
                    `uvm_info("MNT", trans.convert2string(), UVM_DEBUG)
                end
            end
        endtask

    endclass

    class gcd_output_agent extends uvm_agent;
        `uvm_component_utils(gcd_output_agent)

        gcd_ouput_driver  drv;
        gcd_output_monitor mnt;

        function new(string name = "gcd_output_agent", uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            drv = gcd_ouput_driver::type_id::create("drv", this);
            mnt = gcd_output_monitor::type_id::create("mnt", this);
        endfunction
    
        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            drv.seq_item_export.connect(mnt.exit_port);
        endfunction

    endclass

    class gcd_rst_transaction extends uvm_sequence_item;
        `uvm_object_utils(gcd_rst_transaction)

        function new(string name="gcd_rst_transaction");
            super.new(name);
        endfunction

    endclass

    class gcd_rst_monitor extends uvm_monitor;
        `uvm_component_utils(gcd_rst_monitor)

        virtual gcd_interface gcd_if;
        uvm_analysis_port #(gcd_rst_transaction) exit_port

        function new(string name="gcd_rst_monitor", uvm_component parent=null);
            super.new(name, parent);
            exit_port = new("exit_port", this);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual gcd_interface)::get(this, "", "vif", gcd_if)) begin
                `uvm_fatal("RST", "Interface not found")
            end
        endfunction

        task run_phase(uvm_phase phase);
            gcd_rst_transaction trans;
            forever begin
                @(negedge gcd_if.rst_n); // Wait for the drop
                `uvm_info("RST", "[ON]", UVM_MEDIUM)
                exit_port.write(gcd_rst_transaction::type_id::create("trans"));
                @(posedge gcd_if.rst_n);
                `uvm_info("RST", "[OFF]", UVM_MEDIUM)
            end
        endtask
        
    endclass

    `uvm_analysis_imp_decl(_in)
    `uvm_analysis_imp_decl(_out)
    `uvm_analysis_imp_decl(_rst)

    class gcd_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(gcd_scoreboard)

        bit running;
        int expected_trans;
        int success, fail;
        bit [DATA_WIDTH -1 : 0] expected_out;
        uvm_analysis_imp_in  #(gcd_input_transaction,  gcd_scoreboard) entry_port_in;
        uvm_analysis_imp_out #(gcd_output_transaction, gcd_scoreboard) entry_port_out;
        uvm_analysis_imp_rst #(gcd_rst_transaction,    gcd_scoreboard) entry_port_rst;

        function new(string name = "gcd_scoreboard", uvm_component parent = null);
            super.new(name, parent);
            entry_port_in  = new("entry_port_in",  this);
            entry_port_out = new("entry_port_out", this);
            entry_port_rst = new("entry_port_rst", this);
            running = 0;
            success = 0;
            fail = 0;
            expected_out = 0;
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

        function bit [WIDTH-1:0] compute_gcd(bit [WIDTH-1:0] a, bit [WIDTH-1:0] b);
            if (a == 0 || b == 0) return (a == 0) ? b : a; 

            while (b != 0) begin
                bit [WIDTH-1:0] temp = b;
                b = a % b;
                a = temp;
            end

            return a;
        endfunction

        function void write_in(gcd_input_transaction t);
            entry_port_in.write(t);
            `uvm_info("SCB", $sformatf("[IN] A %d B %d", t.a, t.b), UVM_HIGH)
            expected_out = GCD(t.a, t.b);
            running = 1;
        endfunction

        function void write_out(gcd_output_transaction t);
            entry_port_out.write(t);
            if (t.gcd == expected_out) begin
                success += 1;
                `uvm_info("SCB", $sformatf("[OUT] CORRECT"), UVM_HIGH)
            end else begin
                fail += 1;
                `uvm_error("SCB", $sformatf("[OUT] exp %d got %d", expected_out, t.gcd))
            end
            running = 0;
        endfunction

        function void write_rst(gcd_rst_transaction t);
            `uvm_info("SCB", "[RST] golden model reset", UVM_HIGH)
            success += running;
            running = 0;
        endfunction

    endclass

    class gcd_cov_controller extends uvm_component;
        `uvm_component_utils(gcd_cov_controller)

        uvm_analysis_imp_in  #(gcd_input_transaction,  gcd_cov_controller) entry_port_in;
        uvm_analysis_imp_out #(gcd_output_transaction, gcd_cov_controller) entry_port_out;

        function new(string name="gcd_cov_controller", uvm_component parent=null);
            super.new(name, parent);
            entry_port_in  = new("entry_port_in",  this);
            entry_port_out = new("entry_port_out", this);
            cov_in  = new();
            cov_out = new();
        endfunction

        covergroup cov_in with function sample(
            bit [DATA_WIDTH -1 : 0] a, 
            bit [DATA_WIDTH -1 : 0] b
        );
            
            cp_equal:   coverpoint (a != 0 && b != 0 && a == b) {
                bins hit = {1}; 
            }
            cp_a_gt_b:  coverpoint (a > b) {
                bins hit = {1};
            }
            cp_b_gt_a:  coverpoint (b > a) {
                bins hit = {1};
            }

            cp_a:       coverpoint a {
                bins zero  = {0};
                bins full  = {'1};
                bins other = default;
            }
            cp_b:       coverpoint b {
                bins zero  = {0};
                bins full  = {'1};
                bins other = default;
            }

            cross_a_b:     cross cp_a, cp_b {
                bins zero  = binsof(cp_a.zero ) && binsof(cp_b.zero );
                bins full  = binsof(cp_a.full ) && binsof(cp_b.full );
                bins other = binsof(cp_a.other) && binsof(cp_b.other);

                ignore_bins ignored = default; 
            };
        endgroup

        virtual function void write_in(gcd_input_transaction t);
            cov_in.sample(t.a, t.b);
        endfunction
        
        covergroup cov_out with function sample(
            bit [DATA_WIDTH -1 : 0] gcd
        );
            cp_gcd: coverpoint gcd {
                bins zero  = {0};
                bins prime = {1};
                bins other = default;
            }
        endgroup

        virtual function void write_out(gcd_output_transaction t);
            cov_out.sample(t.gcd);
        endfunction

    endclass

    class gcd_env extends uvm_env;
        `uvm_component_utils(gcd_env)

        gcd_input_agent  input_agent;
        gcd_output_agent output_agent;
        gcd_rst_monitor  mnt_rst;
        gcd_scoreboard   scb;
        gcd_cov_controller cov;

        function new(string name = "gcd_env", uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            input_agent = gcd_input_agent::type_id::create("input_agent", this);
            output_agent = gcd_output_agent::type_id::create("output_agent", this);
            mnt_rst = gcd_rst_monitor::type_id::create("mnt_rst", this);
            scb = gcd_scoreboard::type_id::create("scb", this);
            cov = gcd_cov_controller::type_id::create("cov", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            input_agent.mnt.exit_port.connect(scb.entry_port_in);
            output_agent.mnt.exit_port.connect(scb.entry_port_out);
            mnt_rst.exit_port.connect(scb.entry_port_rst);
            scb.entry_port_in.connect(cov.analysis_export);
            scb.entry_port_out.connect(cov.analysis_export);
        endfunction

    endclass


endpackage

import uvm_pkg::*;
import gcd_pkg::*;

module gcd_top;

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

    gcd_interface gcd_if(clk, rst_n);
    

endmodule