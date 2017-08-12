`timescale 1us/100ns

module testbench ();

    initial begin
        $dumpfile("testbench.vcd");
        $dumpvars(0, testbench);
    end

    reg [0:0] clk_12mhz = 0;
    reg [0:0] resetn    = 0;
    initial begin
        // pull reset if available
        resetn = 0;
        repeat(10) #1 clk_12mhz = !clk_12mhz;
        // release reset if available
        resetn = 1;
        forever #1 clk_12mhz = !clk_12mhz;
    end

    localparam FCLK = 100;
    localparam BAUDRATE = 15;
    localparam HALFBITTIME = FCLK / BAUDRATE / 2;


    top /*#(.CPOL           (CPOL),
                .CPHA           (CPHA),
                .LSBFIRST       (LSBFIRST),
                .TIMEOUT__NOT_CS(0),
                .TIMEOUT_CYCLES (1)) // */
    DUT (.clk_12mhz (clk_12mhz),
         .btn1(1),
         .btn2(1),
         .rpi_ice_mosi(1),
         .rpi_ice_miso(1),
         .rpi_ice_clk(1),
         .rpi_ice_ss(1)
         );

    initial begin
        #1000 $finish;
    end

    always @(posedge done) begin
        if (read_value == read_value_expected)
            $display("pass: value: %c, is_first_byte: %b", read_value, first_byte);
        else
            $display("fail: value(expected): %c / 0x%X (%c / 0x%X), first_byte: %b(%b)", read_value, read_value, read_value_expected, read_value_expected, first_byte, first_byte_expected);
    end

endmodule
