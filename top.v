

module top (
    input clk_12mhz,
          btn1, btn2,
          rpi_ice_mosi, rpi_ice_miso, rpi_ice_clk, rpi_ice_ss,
    output reg led1, led2, led3, pmod1_1, pmod1_2,
               pmod4_1, pmod4_2, pmod4_3, pmod4_4,
               pmod4_9, pmod4_10, pmod4_11, pmod4_12,
               
//    output reg [31:0] P6,
//    output reg [31:0] P8,
    // memory interface to SRAM on back side of the board
//    output n_mem_CE, n_mem_WE, n_mem_OE, n_mem_LB, n_mem_UB,
    output [15:0] mem_data
//    output [15:0] mem_data  // set to IO by SB_IO primitive */
    );


// (external) SRAM memory interface

/*    wire [15:0] mem_data_in;
    wire [15:0] mem_data_out;
    wire [15:0] mem_data_oe;
    SB_IO #(
        .PIN_TYPE(6'b 1010_01),
        .PULLUP  (1'b 0)
    ) tristate_io [15:0] (
        .PACKAGE_PIN  (mem_data),
        .OUTPUT_ENABLE(mem_data_oe),
        .D_OUT_0      (mem_data_out),
        .D_IN_0       (mem_data_in)
    );


    reg  [16:0] r_address = 0;
    wire  [7:0] r_data;
    reg   [0:0] r_request = 0;
    wire  [0:0] r_started;
    wire  [0:0] r_done;

    reg  [16:0] w_address = 0;
    reg   [7:0] w_data    = 0;
    reg   [0:0] w_request = 0;
    wire  [0:0] w_started;
    wire  [0:0] w_done;

    wire [15:0] hw_address;
    wire  [0:0] hw_n_cs;
    wire  [0:0] hw_n_we;
    wire  [0:0] hw_n_oe;
    wire  [0:0] hw_n_ub;
    wire  [0:0] hw_n_lb;
    wire [15:0] hw_data_out;
    wire  [0:0] hw_data_oe;

    RAM_IS61WV6416BLL memory(
    .clk(clk), .n_reset(resetn),

    .w_address(w_address), .w_data(w_data),
    .w_request(w_request), .r_started(r_started), .w_done(w_done),

    .r_address(r_address), .r_data(r_data),
    .r_request(r_request), .w_started(w_started), .r_done(r_done),

    .hw_n_cs(hw_n_cs), .hw_n_we(hw_n_we), .hw_n_oe(hw_n_oe),
    .hw_n_ub(hw_n_ub), .hw_n_lb(hw_n_lb),

    .hw_address  (hw_address),
    .hw_data_in  (mem_data_in),
    .hw_data_out (hw_data_out),
    .hw_data_oe  (hw_data_oe));

    assign mem_data_out = hw_data_out;
    assign mem_data_oe  = hw_data_oe && btn1; // safety measure, set port to output
                                              // only as long as btn1 is pressed
    assign mem_addr     = hw_address;
    assign n_mem_CE     = hw_n_cs;
    assign n_mem_OE     = hw_n_oe;
    assign n_mem_WE     = hw_n_we;
    assign n_mem_UB     = hw_n_ub;
    assign n_mem_LB     = hw_n_lb;
// */


// block ram instantiation
    parameter ADDR_WIDTH = 14;
    parameter DATA_WIDTH = 8;
    reg  [7:0] data_in = 0;
    reg  [ADDR_WIDTH-1:0] addr_in = 12;
    reg  [ADDR_WIDTH-1:0] addr_out = 0;
    wire [7:0] data_out;
    bram #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH))
    memory_inst (.clk(clk), .read(), .write(), .addr_in(addr_in), .data_in(data_in), .addr_out(addr_out), .data_out(data_out));


// Clock Generation
    localparam FCLK = 17000000; // required for several timing calculations, depends
    wire [0:0] pll_locked;      //  on pll_config.v content which is generated using
    wire [0:0] clk_pll;         //  icepll -mf pll_config.v -o 17
    pll pll_inst (.clock_in (clk_12mhz), .clock_out(clk_pll), .locked(pll_locked));

    wire [0:0] clk;             //  clock actually used
//    assign clk = clk_pll;     // use pll generated clock (regular mode)
    assign clk = clk_12mhz;     // use clock directly (for use within testbench)


// Reset Generator
    reg [3:0] resetn_gen = 0;
    reg [0:0] resetn;
    always @(posedge clk) begin
        resetn <= &resetn_gen;
        resetn_gen <= {resetn_gen[2:0], pll_locked};
    end


// FPS-clock
    localparam FPS = 20;
    reg [0:0] fps_clk;
    clk_gen #(.CLK_CYCLES(FCLK / FPS)) fps_clk_inst (.clk(clk), .resetn(resetn), .clk_out(fps_clk));


// ws2812b output
    localparam STRIPE_COUNT = 3;
    localparam LEDCOUNT = 2;
    reg  [$clog2(LEDCOUNT)-1:0] LED_counter = 0;
    wire [0:0] bitstream_read;
    reg  [0:0] bitstream_available = 0;
    reg  [0:0] start = 0;
    reg  [0:0] next_LED = 0;
    reg  [24*STRIPE_COUNT-1:0] bitstream;
    reg  [$clog2(STRIPE_COUNT-1):0] next_byte_to_read;
    // generation of the bitstream
    always @(posedge clk) begin
        if (!resetn) begin
            LED_counter <= 0;
            start <= 0;
            next_LED <= 0;
            bitstream_available <= 0;
        end else begin
            if (start) begin
                start <= 0;
                bitstream_available <= 0;
                next_LED <= 1;
                next_byte_to_read <= 0;
            end
            if (next_LED && (bitstream_read || (next_byte_to_read < STRIPE_COUNT*3))) begin
                // build bitstream for next LEDs
                if (next_byte_to_read < STRIPE_COUNT*3) begin
	                next_byte_to_read <= next_byte_to_read + 1;
                end else begin
	                next_byte_to_read <= 0;
	                next_LED <= 0;
	                bitstream_available <= 1;
	                LED_counter <= LED_counter - 1;
                end
                addr_out <= next_byte_to_read;
                bitstream <= {bitstream[24*STRIPE_COUNT-1:8], data_out};

                // build bitstream for next LED
/*                bitstream <= 2*{2'b0, green_int[0], 5'b0,
                                2'b0, red_int[0],   5'b0,
                                2'b0, blue_int[0],  5'b0};// */
            end
            if (fps_clk) begin //  & !LED_counter) begin
                // after sending all LEDs wait for the fps_clk signal
                LED_counter <= LEDCOUNT;
                start       <= 1;
            end
        end
    end
    // actual output of the bitstream
    wire [STRIPE_COUNT-1:0] ws2812b_data;
    wire [3:0]              ws2812b_debug_info;
    ws2812b_out_parallel_module #(
//    ws2812b_out_module #(
        .STRIPECOUNT  (STRIPE_COUNT),
        .CYCLES_SHORT (FCLK/2500000), //  ~0.4 us
        .CYCLES_LONG  (FCLK/1250000), //  ~0.8 us
        .CYCLES_RET   (0))           // ~50 us, but realized using clk_fps
    ws2812b_out_inst (
                     .clk                 (clk),
                     .resetn              (resetn),
                     .bitstream_available (bitstream_available),
                     .bitstream           (bitstream),
                     .bitstream_read      (bitstream_read),
                     .ws2812b_data        (ws2812b_data),
                     .ws2812b_data        (pmod1_2),
                     .debug_info          (ws2812b_debug_info)
                    );
//    assign pmod1_1 = pmod1_2;
    assign pmod1_1 = ws2812b_data[0];
    assign pmod1_2 = ws2812b_data[1];


    reg [3:0]  mem_dbgout;
    reg [0:0]  mem_dbgclk;
    reg [4:0]  mem_dbgcnt;
    reg [31:0] mem_dbgbuf;
    always @(posedge clk) begin
        if (!resetn) begin
            mem_dbgcnt <= 0;
            mem_dbgclk <= 0;
            mem_dbgout <= 0;
//        end    else if (debugdooutput) begin
        end    else if (fps_clk) begin
            mem_dbgbuf <= spi_buffer;
//            mem_dbgbuf <= 32'h1248;
            mem_dbgcnt <= 1;
            mem_dbgout <= 15;
        end else if ((|mem_dbgcnt) && (mem_dbgcnt < 9)) begin
            mem_dbgcnt <= mem_dbgcnt + 1;
            mem_dbgclk <= mem_dbgcnt[0];
            mem_dbgout <= mem_dbgbuf[3:0];
            mem_dbgbuf <= {mem_dbgbuf[3:0], mem_dbgbuf[31:4]};
        end else begin
            mem_dbgcnt <= 0;
            mem_dbgclk <= 0;
            mem_dbgout <= 0;
        end
    end


    // instantiation of a SPI slave
    localparam CPOL = 0;
    localparam CPHA = 0;
    localparam LSBFIRST = 0;
    localparam TIMEOUT__NOT_CS = 1;   // 0: use CS, 1: use timeout
    localparam SPI_TIMEOUT_us = 1000; // when to finish a transmitted frame

    wire [7:0] spi_value;
    wire [7:0] spi_debug_info;
    wire [0:0] spi_first_byte;
    wire [0:0] spi_done;
    wire [0:0] spi_timeout;
    reg [31:0] spi_buffer;

    always @(posedge clk) begin
        if (!resetn) begin

        end
        else begin
            // blockram variant
            if (spi_done) begin
                data_in  <= spi_value;
                addr_in  <= addr_in + 1;
            end else if (spi_timeout) begin
                addr_in    <= 2**ADDR_WIDTH-1;
            end

            // external SRAM variant
/*            if (spi_done) begin
                w_data     <= spi_value;
                w_address  <= 0;
                w_request  <= 1;
            end else if (w_done) begin
                w_request  <= 0;
                w_address  <= w_address + 1;
                addr_in    <= addr_out +1;
            end else if (spi_timeout) begin
                w_address  <= 0;
                addr_in    <= 0;
            end // */

/*            if (spi_done) begin
                spi_buffer <= {spi_buffer[23:0], spi_value};
            end
            if (spi_timeout) begin
                green[ 7: 0] <= spi_buffer[ 7: 0];
                blue [15: 8] <= spi_buffer[15: 8];
                green[23:16] <= spi_buffer[23:15];
                blue [31:24] <= spi_buffer[31:24];
            end // */
        end
    end


    spi_slave #(.CPOL           (CPOL),
                .CPHA           (CPHA),
                .LSBFIRST       (LSBFIRST),
                .TIMEOUT__NOT_CS(1-TIMEOUT__NOT_CS),
                .TIMEOUT_CYCLES ((FCLK * SPI_TIMEOUT_us) / 1000000))
    spi_slave_int (.clk             (clk),
                   .resetn          (resetn),
                   .spi_clk         (rpi_ice_clk),
                   .spi_mosi        (rpi_ice_mosi),
                   .spi_cs          (rpi_ice_ss),
                   .read_value      (spi_value),
                   .done            (spi_done),
                   .timeout_expired (spi_timeout),
                   .first_byte      (spi_first_byte),
                   .debug_info      (spi_debug_info)
                   );

    reg [7:0] last_spi_value;
    reg [0:0] ram_read_step;
    always @(posedge clk) begin
        if (fps_clk) begin
            // alternatively writing to RAM and output from there
            addr_out <= 0;
            ram_read_step <= 1;
        end
        if (ram_read_step == 1) begin
            last_spi_value <= data_out;
        end
    end

    assign {pmod4_12, pmod4_11, pmod4_10, pmod4_9,
            pmod4_4, pmod4_3, pmod4_2, pmod4_1} = //debug_info;
//            {ws2812b_debug_info,
//            {start, |next_byte_to_read, next_byte_to_read[1:0],
//            {start, next_byte_to_read[2:0],
//            {bitstream_read, start, bitstream_available, next_LED,
//            {spi_debug_info[3:0],
//            {spi_debug_info[7:4],
//            {spi_value[3:0],
            {spi_done, last_spi_value[2:0],
//            {spi_first_byte, rpi_ice_ss, mem_dbgcnt[1:0],
//            {n_mem_CE, n_mem_OE, n_mem_WE, btn2,
//            {w_done, w_request, r_done, r_request,
//            {mem_dbgout[2:0], pmod1_2,
//            {mem_dbgcnt,
//            {data_out[3:0],
//            {mem_addr[3:0],
//            {mem_data_in[7:4],
//            {w_request, w_started, r_request, r_started,
//            {hw_n_oe, hw_n_cs, r_started, r_request,
//            {0, 0, fps_clk, pmod1_1,
//             r_done || w_done, rpi_ice_mosi, rpi_ice_clk, resetn};
//             pmod1_1, rpi_ice_mosi, rpi_ice_clk, resetn};
             pmod1_1, rpi_ice_mosi, rpi_ice_clk, rpi_ice_ss};
    assign mem_data = {8'b0, last_spi_value};
//    assign {n_mem_CE, n_mem_WE, n_mem_LB, n_mem_UB, n_mem_OE} = {last_spi_value[4:0]};

    // assign pins to value of leds
//    assign {led3, led2, led1} = {rpi_ice_ss, rpi_ice_ss, fps_clk};
    assign {led3, led2, led1} = last_spi_value[2:0];
endmodule

