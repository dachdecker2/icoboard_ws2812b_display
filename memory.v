/*****************************************************************************\
*
*  interface to IS61WV6416BLL-10TLI 64kx16 bit SRAM
* 
*  instantiation side: 128kx8 bit
*
*  the clk input is MUST NOT be faster than 100 MHz
*  the inputs may be reset after 1 cycle
*
*  transition chains:
*    read
*      done
*      read request (higher priority then write request)
*      set outputs to memory
*      read reply, reset outputs
*      done
*
*    write
*      done
*      write request
*      enable data output
*      set outputs
*      reset outputs
*      done
*
\*****************************************************************************/

module RAM_IS61WV6416BLL (
    // communication from/to instantiation
    input       [0:0] clk,         // clock
    input       [0:0] n_reset,     // global reset         (low active)
    // reading from memory
    input      [16:0] w_address,   // Address Input
    input       [7:0] w_data,      // Data bi-directional
    input       [0:0] w_request,   // request Input
    output reg  [0:0] w_started,   // started writing
    output reg  [0:0] w_done,      // write done
    // writing to memory
    input      [16:0] r_address,   // Address Input
    output reg  [7:0] r_data,      // Data bi-directional
    input       [0:0] r_request,   // request Input
    output reg  [0:0] r_started,   // started reading
    output reg  [0:0] r_done,      // reply done

    // communication to actual SRAM (harware)
    output reg [15:0] hw_address,  // Address Input
    output reg  [0:0] hw_n_cs,     // Chip Select          (low active)
    output reg  [0:0] hw_n_we,     // Write Enable         (low active)
    output reg  [0:0] hw_n_oe,     // Output Enable        (low active)
    output reg  [0:0] hw_n_ub,     // upper byte selection (low active)
    output reg  [0:0] hw_n_lb,     // lower byte selection (low active)
    input      [15:0] hw_data_in,  // data input
    output reg [15:0] hw_data_out, // data output
    output reg  [0:0] hw_data_oe   // direction of iCE40 data pins
);

    reg [0:0] counter = 0;
    reg [0:0] r_request_int = 0;
    reg [0:0] w_request_int = 0;

    always @ (posedge clk) begin
        if (!n_reset) begin
            r_done  <= 0;
            w_done  <= 0;
            hw_n_we <= 1;
            hw_n_oe <= 1;
            hw_n_cs <= 1;
            counter <= 0;
        end else begin
            if (counter) begin
                counter <= counter-1;
            end else begin
                if (r_done || w_done) begin
                    // reset done signals after one cycle and
                    //  request buffers at the same time
                    r_done        <= 0;
                    w_done        <= 0;
                    r_request_int <= 0;
                    w_request_int <= 0;
                    hw_n_cs       <= 1;
                    hw_data_oe    <= 1;
                    hw_data_oe    <= 1;
                end else if (r_request && hw_n_cs) begin
                    // read request is issued while no access is pending
                    r_request_int <= 1;
                    r_started     <= 1;
                    hw_n_we       <= 1; // todo: access write enable sequentially if required
                    hw_n_oe       <= 0;
                    hw_n_cs       <= 0;
                    hw_n_ub       <=  r_address[16];
                    hw_n_lb       <= !r_address[16];
                    hw_address    <=  r_address[15:0];
                    counter       <= 1;
                end else if (r_request_int && !hw_n_cs) begin
                    // the pending read request should be answered by the SRAM
                    r_started     <= 0;
                    hw_n_oe       <= 1;
                    hw_n_cs       <= 1;
                    r_data        <= hw_n_ub ? hw_data_in[15:8] : hw_data_in[7:0];
                    r_done        <= 1;
                end else if (w_request && hw_n_cs && !hw_data_oe) begin
                    hw_data_oe    <= 1;
                end else if (w_request && hw_n_cs && hw_data_oe) begin
                    // write request is issued while no access is pending
                    w_request_int <= 1;
                    w_started     <= 1;
                    hw_n_we       <= 0; // TODO: access write enable sequentially if required
                    hw_n_oe       <= 1;
                    hw_n_cs       <= 0;
                    hw_data_oe    <= 0;
                    hw_n_ub       <=  r_address[16];
                    hw_n_lb       <= !r_address[16];
                    hw_address    <=  r_address[15:0];
                    hw_data_out   <= {w_data, w_data};
                    counter       <= 1;
                end else if (w_request_int && !hw_n_cs) begin
                    // the pending write request should be answered by the SRAM
                    w_started     <= 0;
                    hw_n_oe       <= 1;
                    hw_n_cs       <= 1;
                    w_done        <= 1;
                end else begin
                    // no request -> nothing to do
                end
            end
        end
    end
endmodule
