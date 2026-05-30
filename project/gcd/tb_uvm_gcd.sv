
`timescale 1ns/1ps
`include "uvm_macros.svh" 

package gcd_const_pkg;
    localparam int unsigned DATA_WIDTH = 32;
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
    
    // clocking
    clocking cb @(posedge clk);
        default input #1step output #0;
        input in_ready, out_valid, gcd_out;
        inout in_valid, a_in, b_in, out_ready;
    endclocking

    // protocol checking
    property p_valid_no_drop(valid, ready);
        @(posedge clk) disable iff (!rst_n || $isunknown(valid) || $isunknown(ready))
        valid && !ready |=> valid;
    endproperty

    property p_data_stable(valid, ready, data);
        @(posedge clk) disable iff (!rst_n || $isunknown(valid) || $isunknown(ready) || $isunknown(data))
        valid && !ready |=> $stable(data);
    endproperty

    property p_control_known(sig);
        @(posedge clk) disable iff (!rst_n)
        !$isunknown(sig);
    endproperty

    // inputs
    chk_in_valid_no_drop: assert property(p_valid_no_drop(in_valid, in_ready))
        else `uvm_error("CHK", "Input Protocol Violation: in_valid dropped without in_ready!")
        
    chk_in_data_stable_a: assert property(p_data_stable(in_valid, in_ready, a_in))
        else `uvm_error("CHK", "Input Protocol Violation: a_in changed while stalled!")
        
    chk_in_data_stable_b: assert property(p_data_stable(in_valid, in_ready, b_in))
        else `uvm_error("CHK", "Input Protocol Violation: b_in changed while stalled!")

    // outputs
    chk_out_valid_no_drop: assert property(p_valid_no_drop(out_valid, out_ready))
        else `uvm_error("CHK", "Output Protocol Violation: out_valid dropped without out_ready!")
        
    chk_out_data_stable: assert property(p_data_stable(out_valid, out_ready, gcd_out))
        else `uvm_error("CHK", "Output Protocol Violation: gcd_out changed while stalled!")

    // known control
    chk_in_valid_known:  assert property(p_control_known(in_valid));
    chk_in_ready_known:  assert property(p_control_known(in_ready));
    chk_out_valid_known: assert property(p_control_known(out_valid));
    chk_out_ready_known: assert property(p_control_known(out_ready));

endinterface

package gcd_pkg;

    import uvm_pkg::*;
    import gcd_const_pkg::*;
    
    // input agent
    class gcd_input_transaction extends uvm_sequence_item;
        `uvm_object_utils(gcd_input_transaction)

        bit [DATA_WIDTH -1 : 0] a, b;
        int unsigned delay_cycles;

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
            while (gcd_if.cb.in_ready !== 1'b1) begin
                @(posedge gcd_if.cb);
            end
            repeat (trans.delay_cycles) @(posedge gcd_if.cb);
            gcd_if.cb.in_valid  <= 1'b1;
            gcd_if.cb.a_in      <= trans.a;
            gcd_if.cb.b_in      <= trans.b;
            do begin
                @(posedge gcd_if.cb);
            end while (gcd_if.cb.in_ready !== 1'b1);
            gcd_if.cb.in_valid  <= 1'b0;
        endtask

        task run_phase(uvm_phase phase);
            gcd_input_transaction trans;
            forever begin
                wait(!gcd_if.rst_n);
                gcd_if.cb.in_valid <= 1'b0;
                gcd_if.cb.a_in     <= 0;
                gcd_if.cb.b_in     <= 0;
                wait(gcd_if.rst_n);
                @(posedge gcd_if.cb);
                fork
                    begin
                        forever begin
                            seq_item_port.get_next_item(trans);
                            `uvm_info("DRV", trans.convert2string(), UVM_HIGH)
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
        uvm_analysis_port #(gcd_input_transaction) exit_port;

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
                @(posedge gcd_if.cb);
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
        `uvm_component_utils(gcd_input_agent)

        uvm_sequencer #(gcd_input_transaction)  sqr;
        gcd_input_driver                        drv;
        gcd_input_monitor                       mnt;

        function new(string name = "gcd_input_agent", uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sqr = uvm_sequencer#(gcd_input_transaction)::type_id::create("sqr", this);
            drv = gcd_input_driver::type_id::create("drv", this);
            mnt = gcd_input_monitor::type_id::create("mnt", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            drv.seq_item_port.connect(sqr.seq_item_export);
        endfunction

    endclass

    // output agent
    class gcd_output_transaction extends uvm_sequence_item;
        `uvm_object_utils(gcd_output_transaction)

        bit [DATA_WIDTH -1 : 0] gcd;
        int unsigned delay_cycles;

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
            while (gcd_if.cb.out_valid !== 1'b1) begin
                @(posedge gcd_if.cb);
            end
            repeat (trans.delay_cycles) @(posedge gcd_if.cb);
            gcd_if.cb.out_ready <= 1'b1;
            do begin
                @(posedge gcd_if.cb);
            end while (gcd_if.cb.out_valid !== 1'b1);
            gcd_if.cb.out_ready <= 1'b0;
        endtask

        task run_phase(uvm_phase phase);
            gcd_output_transaction trans;
            forever begin
                wait(!gcd_if.rst_n);
                gcd_if.cb.out_ready <= 1'b0;
                wait(gcd_if.rst_n);
                @(posedge gcd_if.cb);
                fork
                    begin
                        forever begin
                            seq_item_port.get_next_item(trans);
                            `uvm_info("DRV", trans.convert2string(), UVM_HIGH)
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
        uvm_analysis_port #(gcd_output_transaction) exit_port;

        function new(string name="gcd_output_monitor", uvm_component parent=null);
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
            gcd_output_transaction trans;
            forever begin
                @(posedge gcd_if.cb);
                `uvm_info("TOP", $sformatf(
                    "[TIME] %0d [A] %h [B] %h [in_v] %b [in_r] %b [out_v] %b [out_r] %b [GCD] %h", 
                    $time(), gcd_if.cb.a_in, gcd_if.cb.b_in, gcd_if.cb.in_valid, gcd_if.cb.in_ready,
                    gcd_if.cb.out_valid, gcd_if.cb.out_ready, gcd_if.cb.gcd_out), UVM_HIGH)
                if (gcd_if.cb.out_ready && gcd_if.cb.out_valid) begin
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

        uvm_sequencer #(gcd_output_transaction) sqr;
        gcd_ouput_driver                        drv;
        gcd_output_monitor                      mnt;

        function new(string name = "gcd_output_agent", uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sqr = uvm_sequencer#(gcd_output_transaction)::type_id::create("sqr", this);
            drv = gcd_ouput_driver::type_id::create("drv", this);
            mnt = gcd_output_monitor::type_id::create("mnt", this);
        endfunction
    
        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            drv.seq_item_port.connect(sqr.seq_item_export);
        endfunction

    endclass

    // rst agent
    class gcd_rst_transaction extends uvm_sequence_item;
        `uvm_object_utils(gcd_rst_transaction)

        function new(string name="gcd_rst_transaction");
            super.new(name);
        endfunction

    endclass

    class gcd_rst_monitor extends uvm_monitor;
        `uvm_component_utils(gcd_rst_monitor)

        virtual gcd_interface gcd_if;
        uvm_analysis_port #(gcd_rst_transaction) exit_port;

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
                `uvm_info("RST", "[ON]", UVM_LOW)
                exit_port.write(gcd_rst_transaction::type_id::create("trans"));
                @(posedge gcd_if.rst_n);
                `uvm_info("RST", "[OFF]", UVM_LOW)
            end
        endtask
        
    endclass

    // scoreboard
    `uvm_analysis_imp_decl(_in)
    `uvm_analysis_imp_decl(_out)
    `uvm_analysis_imp_decl(_rst)

    class gcd_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(gcd_scoreboard)

        bit running;
        int unsigned expected_trans;
        int unsigned success, fail;
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
            if (!uvm_config_db#(int unsigned)::get(this, "", "expected_trans", expected_trans)) begin
                `uvm_info("SCB", "No target set. SCB will not hold objections.", UVM_LOW)
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
            `uvm_info("SCB", $sformatf("Test Complete! Success: %0d, Fail: %0d", success, fail), UVM_NONE)
        endfunction

        function bit [DATA_WIDTH-1:0] compute_gcd(bit [DATA_WIDTH-1:0] a, bit [DATA_WIDTH-1:0] b);
            if (a == 0 || b == 0) return (a == 0) ? b : a; 

            while (b != 0) begin
                bit [DATA_WIDTH-1:0] temp = b;
                b = a % b;
                a = temp;
            end

            return a;
        endfunction

        function void write_in(gcd_input_transaction t);
            `uvm_info("SCB", $sformatf("[IN] A %d B %d", t.a, t.b), UVM_HIGH)
            expected_out = compute_gcd(t.a, t.b);
            running = 1;
        endfunction

        function void write_out(gcd_output_transaction t);
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

    // coverage controller
    class gcd_cov_controller extends uvm_component;
        `uvm_component_utils(gcd_cov_controller)

        localparam bit [DATA_WIDTH-1:0] MAX_VAL = '1;

        uvm_analysis_imp_in  #(gcd_input_transaction,  gcd_cov_controller) entry_port_in;
        uvm_analysis_imp_out #(gcd_output_transaction, gcd_cov_controller) entry_port_out;

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

            cp_a: coverpoint a {
                bins zero  = {0};
                bins full  = {MAX_VAL};
                bins other = {[1 : MAX_VAL-1]}; 
            }

            cp_b: coverpoint b {
                bins zero  = {0};
                bins full  = {MAX_VAL};
                bins other = {[1 : MAX_VAL-1]}; 
            }

            cross_a_b:     cross cp_a, cp_b {
                option.cross_auto_bin_max = 0;

                bins zero  = binsof(cp_a.zero ) && binsof(cp_b.zero );
                bins full  = binsof(cp_a.full ) && binsof(cp_b.full );
                bins other = binsof(cp_a.other) && binsof(cp_b.other);
            }
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

        function new(string name="gcd_cov_controller", uvm_component parent=null);
            super.new(name, parent);
            entry_port_in  = new("entry_port_in",  this);
            entry_port_out = new("entry_port_out", this);
            cov_in  = new();
            cov_out = new();
        endfunction

    endclass

    // environment
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
            input_agent.mnt.exit_port.connect(cov.entry_port_in);
            
            output_agent.mnt.exit_port.connect(scb.entry_port_out);
            output_agent.mnt.exit_port.connect(cov.entry_port_out);

            mnt_rst.exit_port.connect(scb.entry_port_rst);
        endfunction

    endclass

    // deterministic sequences
    class gcd_det_in_seq extends uvm_sequence #(gcd_input_transaction);
        `uvm_object_utils(gcd_det_in_seq)

        int unsigned predefined_a[]     = '{15, 0, 25, '1, 12};
        int unsigned predefined_b[]     = '{5, 10, 25, '1, 18};
        int unsigned predefined_delay[] = '{0,  0,  0,  0,  0};

        function new(string name="gcd_det_in_seq");
            super.new(name);
        endfunction

        task body();
            gcd_input_transaction trans;
            int unsigned num_trans = predefined_a.size();
            if (predefined_a.size() != predefined_b.size() || predefined_a.size() != predefined_delay.size()) begin
                `uvm_error("SEQ", "input sizes do not match")
            end
            `uvm_info("SEQ", $sformatf("%0d transactions", num_trans), UVM_MEDIUM)
            for (int unsigned i = 0; i < num_trans; i++) begin
                trans = gcd_input_transaction::type_id::create("trans");
                start_item(trans);
                trans.a            = predefined_a[i];
                trans.b            = predefined_b[i];
                trans.delay_cycles = predefined_delay[i];
                finish_item(trans);
            end
            `uvm_info("SEQ", $sformatf("DONE"), UVM_MEDIUM)
        endtask

    endclass

    class gcd_det_out_seq extends uvm_sequence #(gcd_output_transaction);
        `uvm_object_utils(gcd_det_out_seq)

        int unsigned predefined_delay[] = '{0,  0,  0,  0,  0};
        
        function new(string name="gcd_det_out_seq");
            super.new(name);
        endfunction

        task body();
            gcd_output_transaction trans;
            int unsigned num_trans = predefined_delay.size();
            `uvm_info("SEQ", $sformatf("%0d transactions", num_trans), UVM_MEDIUM)
            for (int unsigned i = 0; i < num_trans; i++) begin
                trans = gcd_output_transaction::type_id::create("trans");
                start_item(trans);
                trans.gcd          = 0;
                trans.delay_cycles = predefined_delay[i];
                finish_item(trans);
            end
            `uvm_info("SEQ", $sformatf("DONE"), UVM_MEDIUM)
        endtask

    endclass

    class gcd_det_vseq extends uvm_sequence;
        `uvm_object_utils(gcd_det_vseq)

        int unsigned predefined_a[]         = '{15, 6};
        int unsigned predefined_b[]         = '{5, 10};
        int unsigned predefined_delay_in[]  = '{0,  0};
        int unsigned predefined_delay_out[] = '{0,  1};

        uvm_sequencer #(gcd_input_transaction)  p_in_sqr;
        uvm_sequencer #(gcd_output_transaction) p_out_sqr;

        function new(string name="gcd_det_vseq");
            super.new(name);
        endfunction

        task body();
            gcd_det_in_seq  in_seq;
            gcd_det_out_seq out_seq;
            in_seq  = gcd_det_in_seq::type_id::create("in_seq");
            out_seq = gcd_det_out_seq::type_id::create("out_seq");

            in_seq.predefined_a     = predefined_a;
            in_seq.predefined_b     = predefined_b;
            in_seq.predefined_delay = predefined_delay_in;

            out_seq.predefined_delay = predefined_delay_out;

            `uvm_info("VSEQ", "Starting deterministic input and output sequences...", UVM_LOW)

            fork
                in_seq.start(p_in_sqr);
                out_seq.start(p_out_sqr);
            join
            
            `uvm_info("VSEQ", "All deterministic transactions completed.", UVM_LOW)
        endtask

    endclass

    // random sequences
    class gcd_rnd_in_seq extends uvm_sequence #(gcd_input_transaction);
        `uvm_object_utils(gcd_rnd_in_seq)

        int unsigned num_trans = 10;
        int unsigned min_a     = 0, max_a     = 0;
        int unsigned min_b     = 0, max_b     = 0;
        int unsigned min_delay = 0, max_delay = 0;

        function new(string name="gcd_rnd_in_seq");
            super.new(name);
        endfunction

        task body();
            gcd_input_transaction trans;
            `uvm_info("SEQ", $sformatf("%d transactions, a [%d:%d], b [%d:%d], delay [%d:%d]", num_trans, min_a, max_a, min_b, max_b, min_delay, max_delay), UVM_MEDIUM)
            repeat (num_trans) begin
                `uvm_do_with(trans, {
                    a            inside {[min_a : max_a]};
                    b            inside {[min_b : max_b]};
                    delay_cycles inside {[min_delay : max_delay]};
                })
            end
            `uvm_info("SEQ", $sformatf("DONE"), UVM_MEDIUM)
        endtask

    endclass

    class gcd_rnd_out_seq extends uvm_sequence #(gcd_output_transaction);
        `uvm_object_utils(gcd_rnd_out_seq)

        int unsigned num_trans = 10;
        int unsigned min_delay   = 0, max_delay   = 0;

        function new(string name="gcd_rnd_out_seq");
            super.new(name);
        endfunction

        task body();
            gcd_output_transaction trans;
            `uvm_info("SEQ", $sformatf("%d transactions, delay [%d:%d]", num_trans, min_delay, max_delay), UVM_MEDIUM)
            repeat (num_trans) begin
                `uvm_do_with(trans, {
                    delay_cycles inside {[min_delay : max_delay]};
                })
            end
            `uvm_info("SEQ", $sformatf("DONE"), UVM_MEDIUM)
        endtask
    
    endclass

    class gcd_rnd_vseq extends uvm_sequence;
        `uvm_object_utils(gcd_rnd_vseq)

        int unsigned num_trans = 0;
        int unsigned min_a, max_a;
        int unsigned min_b, max_b;
        int unsigned min_delay_in, max_delay_in;
        int unsigned min_delay_out, max_delay_out;

        uvm_sequencer #(gcd_input_transaction)  p_in_sqr;
        uvm_sequencer #(gcd_output_transaction) p_out_sqr;

        function new(string name="gcd_random_vseq");
            super.new(name);
        endfunction

        task body();
            gcd_rnd_in_seq  in_seq;
            gcd_rnd_out_seq out_seq;
            in_seq  = gcd_rnd_in_seq::type_id::create("in_seq");
            out_seq = gcd_rnd_out_seq::type_id::create("out_seq");
            
            in_seq.num_trans = num_trans;
            in_seq.min_a     = min_a;
            in_seq.max_a     = max_a;
            in_seq.min_b     = min_b;
            in_seq.max_b     = max_b;
            in_seq.min_delay = min_delay_in;
            in_seq.max_delay = max_delay_in;

            out_seq.num_trans = num_trans;
            out_seq.min_delay = min_delay_out;
            out_seq.max_delay = max_delay_out;

            `uvm_info("VSEQ", "Starting randomized input and output sequences...", UVM_LOW)

            fork
                in_seq.start(p_in_sqr);
                out_seq.start(p_out_sqr);
            join
            
            `uvm_info("VSEQ", "All random transactions completed.", UVM_LOW)
        endtask
    endclass

    // bring up test
    class gcd_bringup_test extends uvm_test;
        `uvm_component_utils(gcd_bringup_test)

        gcd_env env;

        function new(string name = "gcd_bringup_test", uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = gcd_env::type_id::create("env", this);
            uvm_config_db#(int unsigned)::set(null, "*scb*", "expected_trans", 2); 
        endfunction

        task run_phase(uvm_phase phase);
            gcd_det_vseq det_seq;
            phase.raise_objection(this);
            det_seq = gcd_det_vseq::type_id::create("det_seq");
            det_seq.p_in_sqr  = env.input_agent.sqr;
            det_seq.p_out_sqr = env.output_agent.sqr;
            det_seq.predefined_a         = '{15, 6};
            det_seq.predefined_b         = '{5, 10};
            det_seq.predefined_delay_in  = '{0,  0};
            det_seq.predefined_delay_out = '{0,  0};
            det_seq.start(null);
            phase.drop_objection(this);
        endtask

    endclass
    
    // determistic test
    class gcd_det_test extends uvm_test;
        `uvm_component_utils(gcd_det_test)

        gcd_env env;

        function new(string name = "gcd_det_test", uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = gcd_env::type_id::create("env", this);
            uvm_config_db#(int unsigned)::set(null, "*scb*", "expected_trans", 16); 
        endfunction

        task run_phase(uvm_phase phase);
            gcd_det_vseq det_seq;
            phase.raise_objection(this);
            det_seq = gcd_det_vseq::type_id::create("det_seq");
            det_seq.p_in_sqr  = env.input_agent.sqr;
            det_seq.p_out_sqr = env.output_agent.sqr;
            det_seq.predefined_a         = '{0, 1, 0, 5, 8, 5, 6,  7, 1, 1, 1, 1, 2, 2, 2, 2};
            det_seq.predefined_b         = '{0, 0, 1, 6, 3, 5, 2, 28, 1, 1, 1, 1, 2, 2, 2, 2};
            det_seq.predefined_delay_in  = '{0, 0, 0, 0, 0, 0, 0,  0, 1, 1, 1, 1, 4, 4, 4, 4};
            det_seq.predefined_delay_out = '{0, 0, 0, 0, 0, 0, 0,  0, 4, 4, 4, 4, 1, 1, 1, 1};
            det_seq.start(null);
            phase.drop_objection(this);
        endtask

    endclass

    // randomized test
    class gcd_rnd_test extends uvm_test;
        `uvm_component_utils(gcd_rnd_test)

        gcd_env env;

        function new(string name = "gcd_rnd_test", uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = gcd_env::type_id::create("env", this);
            uvm_config_db#(int unsigned)::set(null, "*scb*", "expected_trans", 100); 
        endfunction

        task run_phase(uvm_phase phase);
            gcd_rnd_vseq rnd_seq;
            phase.raise_objection(this);
            rnd_seq = gcd_rnd_vseq::type_id::create("rnd_seq");
            rnd_seq.p_in_sqr  = env.input_agent.sqr;
            rnd_seq.p_out_sqr = env.output_agent.sqr;
            rnd_seq.num_trans = 100;
            rnd_seq.min_a     = 0;
            rnd_seq.max_a     = 100;
            rnd_seq.min_b     = 0;
            rnd_seq.max_b     = 100;
            rnd_seq.min_delay_in  = 0;
            rnd_seq.max_delay_in  = 4;
            rnd_seq.min_delay_out = 0;
            rnd_seq.max_delay_out = 4;
            rnd_seq.start(null);
            phase.drop_objection(this);
        endtask

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
        repeat(2) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
    end

    gcd_interface gcd_if(clk, rst_n);
    initial uvm_config_db#(virtual gcd_interface)::set(null, "*", "vif", gcd_if);

    gcd #(
        .WIDTH(DATA_WIDTH)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .in_valid   (gcd_if.in_valid),
        .in_ready   (gcd_if.in_ready),
        .a_in       (gcd_if.a_in),
        .b_in       (gcd_if.b_in),
        .out_valid  (gcd_if.out_valid),
        .out_ready  (gcd_if.out_ready),
        .gcd_out    (gcd_if.gcd_out)
    );

    initial run_test("gcd_bringup_test");

    initial begin
        $dumpfile("waves.vcd"); 
        $dumpvars(0, gcd_top);  
    end

endmodule