
/**************************************************************\
*
*  WS2812 LED controll module
*
*  Parameters:
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

module ws2812b_out_module (
    input            clk,
    input            resetn,
    input            bitstream_available,
    input [23:0]     bitstream,
    output reg       bitstream_read,
    output reg       ws2812b_data,
    output reg [3:0] debug_info
);

    parameter CYCLES_SHORT =   3; //  ~0,44 us @ 9 MHz
    parameter CYCLES_LONG  =   5; //  ~0,66 us @ 9 MHz
    parameter CYCLES_RET   = 450; //  50,0  us @ 9 MHz

    localparam CYCLES_WIDTH = $clog2(CYCLES_RET > CYCLES_LONG ? CYCLES_RET
                                                              : CYCLES_LONG);

    // keep an eye on the length of bitnum
    reg  [4:0] bitnum = 0;     // 0 .. 23
    reg  [CYCLES_WIDTH-1:0] counter = 0;    // 0 .. CYCLES_RET
    reg  [23:0] bitstream_int; // internal copy of the txed LED data

    reg  [0:0] idle = 0;

    always @(posedge clk) begin
        if (!resetn) begin
            // reset state 
            counter <= 0;
            bitstream_read <= 0;
            bitnum <= 0;
        end else begin
            bitstream_read <= 0; // default value
            if (counter != 0) begin
                // wait state: consume the desired time
                counter <= counter - 1;
            end else begin
                if (!bitnum && !ws2812b_data) begin
                    if (bitstream_available) begin
                        // communicate to "caller"
                        bitstream_read <= 1; // state bitstream to be read for this cycle
                        bitstream_int <= bitstream; // get internal copy of bitstream
                        // start output
                        ws2812b_data <= 1;
                        bitnum <= 24;
                        counter <= bitstream[23] ? CYCLES_LONG : CYCLES_SHORT;
                        idle <= 0;
                    end else begin
                        // no new bitstream available -> trigger output of ws2812b LEDs
                        ws2812b_data <= 0;
                        counter <= CYCLES_RET;            // cheaper logic
//                        counter <= idle ? 0 : CYCLES_RET; // immidiate reaction to bitstream available
                        idle <= 1;
                    end
                end else if (bitnum) begin
                    // output the remainder of bitstream
                    if (!ws2812b_data) begin
                        ws2812b_data <= 1;
                        counter <= bitstream_int[23] ? CYCLES_LONG : CYCLES_SHORT;
                    end else begin
                        ws2812b_data <= 0;
                        counter <= (bitstream_int[23]) ? CYCLES_SHORT : CYCLES_LONG;
                        bitstream_int <= {bitstream_int[22:0], bitstream_int[23]};
                        bitnum <= bitnum - 1;
                    end
                end
            end
        end
    end

//    assign debug_info = {bitstream_read, bitstream_available, resetn, clk};
    assign debug_info = {ws2812b_data, bitstream_read, bitstream_available, clk};
endmodule
