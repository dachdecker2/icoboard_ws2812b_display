
/**************************************************************\
*
*  WS2812 LED controll module
*
*  Parameters:
*    STRIPECOUNT count of stripes controlled in parallel
*    CYCLES_SHORT clk cycles for the 400 ns duration
*    CYCLES_LONG  clk cycles for the 800 ns duration
*    CYCLES_RET   clk cycles for the wait time after
*                 clocking the bits out
*
*  inputs:
*    clk                  clock signal
*    resetn               reset signal (low active)
*    bitstream_available  in idle state trigger clocking
*                         out the bitstream supplied
*    bitstream            the bitstream to be clocked out
*
*  outputs:
*    bitstream_read  bitstream has been read and may be updated
*    ws2811_data     the actual output to control the ws2811 LEDs
*    debug_info
*
\**************************************************************/

module ws2812b_out_parallel_module (
    input                        clk,
    input                        resetn,
    input                        bitstream_available,
    input [STRIPECOUNT*24-1:0]   bitstream,
    output reg                   bitstream_read,
    output reg [STRIPECOUNT-1:0] ws2812b_data,
    output reg [3:0]             debug_info
);

    parameter STRIPECOUNT  =   1; // number of parallel stripes
    parameter CYCLES_SHORT =   3; //  ~0,44 us @ 9 MHz
    parameter CYCLES_LONG  =   5; //  ~0,66 us @ 9 MHz
    parameter CYCLES_RET   = 450; //  50,0  us @ 9 MHz

    // obtain the highest number of cycles of CYCLES_LONG or CYCLES_RET
    // for the number of bits needed for the respect counter
    localparam CYCLES_WIDTH = $clog2(CYCLES_RET > CYCLES_LONG ? CYCLES_RET
                                                              : CYCLES_LONG);

    reg  [4:0] bitnum = 0;     // 0 .. 23 number of the actual bit to be transfered
    reg  [1:0] bitstate;       // state during bit transmission:
                               //    0: first  phase: output 1
                               //    1: second phase: output value to be transfered
                               //    2: third  phase: output 0
                               //    leads to transmission of
                               //       long1 + short0 for 1 and
                               //       short1 + long0 for 0
    reg  [CYCLES_WIDTH-1:0] counter = 0;    // 0 .. 2**CYCLES_WIDTH-1
    reg  [STRIPECOUNT*24-1:0] bitstream_int; // internal copy of the to be txed LED data
    reg  [0:0] idle = 1;

//    wire [3:0] debug_info;

    always @(posedge clk) begin
        if (!resetn) begin
            // reset state 
            counter        <= 0;
            bitstream_read <= 0;
            bitnum         <= 0;
            ws2812b_data   <= 0;
        end else begin
            // regular operation
            bitstream_read <= 0; // default value
            if (|counter) begin
                // wait state: consume the desired time
                counter <= counter - 1;
            end else begin
                // operate outputs
                if (!bitnum && bitstream_available) begin
                    // take input date, state that to "caller"
                    bitstream_int <= bitstream; // get internal copy of bitstream
                    bitstream_read <= 1; // state bitstream to be read for this cycle
                    // trigger output of data
                    bitnum <= 24;
                    bitstate <= 0;
                end else if (bitnum) begin
                    // actual output
                    counter <= CYCLES_SHORT;
                    bitstate <= bitstate + 1;
                    if (bitstate == 0) begin
                        ws2812b_data <= STRIPECOUNT*{1'b1};
                    end else if (bitstate == 1) begin
                        ws2812b_data <= bitstream_int[STRIPECOUNT:0];
                    end else if (bitstate == 2) begin
                        ws2812b_data <= STRIPECOUNT*{1'b0};
                        bitnum   <= bitnum - 1;
                        bitstate <= 0;
                        bitstream_int <= {bitstream_int[23:0], bitstream_int[STRIPECOUNT*24-1:24]};
                        if (! bitnum) counter <= CYCLES_RET;
                    end
                end
            end
        end
    end

//    assign debug_info = {bitstream_read, bitstream_available, resetn, clk};
    assign debug_info = {ws2812b_data, bitstream_read, bitstream_available, clk};
endmodule
