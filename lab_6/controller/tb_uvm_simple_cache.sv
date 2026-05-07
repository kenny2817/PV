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
    
    class ctrl_transaction extends uvm_sequence_item;
        `uvm_object_utils(ctrl_transaction)
        
        rand bit                    we;
        rand bit                    req;
        rand logic [ADDR_WIDTH-1:0] addr;
        rand logic [DATA_WIDTH-1:0] wdata;
        
        function new(string name = "ctrl_transaction");
            super.new(name);
        endfunction

        function string convert2string();
            return $sformatf( "M: [%0s] Addr=%0h Data=%0h", (use_m ? (is_write ? "WR" : "RD") : "IDLE"), addr, data );
        endfunction
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
            ctrl_det_seq seq;
            phase.raise_objection(this);
            seq = ctrl_det_seq::type_id::create("seq");
            seq.num_trans = 50;
            seq.start(env.master0_agent.sqr); 
            phase.drop_objection(this);
        endtask
    endclass

    class ctrl_det_seq extends uvm_sequence #(ctrl_transaction);
        `uvm_object_utils(ctrl_det_seq)
        
        int num_trans = 8;

        function new(string name = "ctrl_det_seq");
            super.new(name);
        endfunction

        task body();
            ctrl_transaction req;
            for (int i = 0; i < num_trans; i++) begin
                `uvm_do_with(req, { we == 1; req == 0; addr == i; wdata == (i * 16) + 100; })
                `uvm_do_with(req, { we == 0; req == 1; addr == i; wdata == 0;              })
            end
        endtask
    endclass

    class ctrl_sequencer extends uvm_sequencer #(ctrl_transaction);
        `uvm_component_utils(ctrl_sequencer)
    endclass

    class ctrl_driver extends uvm_driver #(ctrl_transaction);
        `uvm_component_utils(ctrl_driver)

        virtual ctrl_interface ctrl_if; 

        function new(string name = "ctrl_driver", uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual ctrl_interface)::get(this, "", "vif", ctrl_if)) begin
                `uvm_fatal("NOVIF", {"Virtual interface not found for: ", get_full_name()})
            end
        endfunction

        task reset_interface();
            ctrl_if.cb.req   <= 1'b0;
            ctrl_if.cb.we    <= 1'b0;
            ctrl_if.cb.addr  <= '0;
            ctrl_if.cb.wdata <= '0;
        endtask

        task apply(ctrl_transaction req);
            ctrl_if.cb.we       <= req.we;
            ctrl_if.cb.req      <= req.req;
            ctrl_if.cb.addr     <= req.addr;
            ctrl_if.cb.wdata    <= req.wdata;
            @(posedge ctrl_if.clk);
            wait (ctrl_if.cb.gnt === 1'b1);
            ctrl_if.cb.we       <= 1'b0;
            ctrl_if.cb.req      <= 1'b0;
        endtask

        task run_phase(uvm_phase phase);
            this.reset_interface();
            ctrl_transaction req;
            forever begin
                seq_item_port.get_next_item(req);
                this.apply(req);
                seq_item_port.item_done();
            end
        endtask
    endclass

endpackage

import uvm_pkg::*;
import controller_pkg::*;// Parameters must match DUTparameterADDR_WIDTH = 8;parameterDATA_WIDTH = 32;...endmodule: tb_uvm_simple_mem_ctrl
