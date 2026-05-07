module simple_mem_ctrl #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
)(
    input  logic                  clk,
    input  logic                  rst_n,

    // Master 0 (CPU)
    input  logic [ADDR_WIDTH-1:0] addr0,
    input  logic [DATA_WIDTH-1:0] wdata0,
    output logic [DATA_WIDTH-1:0] rdata0,
    input  logic                  we0,
    input  logic                  req0,
    output logic                  gnt0,

    // Master 1 (DMA)
    input  logic [ADDR_WIDTH-1:0] addr1,
    input  logic [DATA_WIDTH-1:0] wdata1,
    output logic [DATA_WIDTH-1:0] rdata1,
    input  logic                  we1,
    input  logic                  req1,
    output logic                  gnt1
);

    // Internal memory array (256 words of 32 bits)
    localparam MEM_SIZE_WORDS = (1 << ADDR_WIDTH);
    logic [DATA_WIDTH-1:0] memory[MEM_SIZE_WORDS];

    // Initialize memory on reset (synchronous initialization). This avoids
    // multiple drivers; the memory is now only written from this always_ff.

    // --- Arbitration Logic (Combinational: M0 priority) ---
    // Gnt0 is high if M0 requests, regardless of M1.
    assign gnt0 = req0; 
    // Gnt1 is high only if M1 requests AND M0 does not request.
    assign gnt1 = req1 && !req0; 

    // Internal wires to select the currently granted master's signals
    logic [ADDR_WIDTH-1:0] selected_addr;
    logic [DATA_WIDTH-1:0] selected_wdata;
    logic selected_we;
    logic selected_gnt;

    // Combine selection into a single compact mux expression
    assign selected_gnt = gnt0 | gnt1;
    // Pack the selected fields together to pick from either master (m0 priority)
    assign { selected_addr, selected_wdata, selected_we }
        = gnt0 ? { addr0,  wdata0,  we0 }
               : { addr1,  wdata1,  we1 };

    // --- Sequential Logic (Memory Access happens on clock edge) ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all memory locations to 0 when reset is asserted (active-low)
            for (int i = 0; i < MEM_SIZE_WORDS; i++) begin
                memory[i] <= '0;
            end
        end else begin
            if (selected_gnt && selected_we) begin
                // Synchronous Write
                memory[selected_addr] <= selected_wdata;
            end
        end
    end

    // --- Read Logic (Asynchronous Read) ---
    // Data is available immediately based on the selected address if it's a read operation
    logic [DATA_WIDTH-1:0] selected_rdata;
    assign selected_rdata = memory[selected_addr];
    
    // Mux for outputs: Provide read data back to the correct master
    // Compact assignment for read-data outputs; use width-matched high-impedance when not driven
    assign { rdata0, rdata1 } = {
        (gnt0 && !we0) ? selected_rdata : {DATA_WIDTH{1'bz}},
        (gnt1 && !we1) ? selected_rdata : {DATA_WIDTH{1'bz}}
    };
    
    // Default assignments for outputs when not granted/reading
    // Assigning 'z (high impedance) is common in simulation environments for unused ports
    // but in synthesis you might tie them low/zero if your environment requires
    // assign rdata0 = (gnt0 && !we0) ? selected_rdata : 32'b0; // Alternative for synthesis

endmodule
