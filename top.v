

module top (
	input clk_12mhz,
	      btn1, btn2,
	      rpi_ice_mosi, rpi_ice_miso, rpi_ice_clk, rpi_ice_ss, rpi_ice_ss2,
	output reg led1, led2, led3, pmod1_1,
               pmod4_1, pmod4_2, pmod4_3, pmod4_4,
               pmod4_7, pmod4_8, pmod4_9, pmod4_10,
    // memory interface to SRAM on back side of the board
	output n_mem_CE, n_mem_WE, n_mem_OE, n_mem_LB, n_mem_UB,
    output [15:0] mem_addr,
    output [15:0] mem_data  // set to IO by SB_IO primitive
	);

	wire [15:0] mem_data_in;
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

	// Clock Generation
	localparam FCLK = 21000000; // required for several timing calculations, depends
	wire [0:0] pll_locked;      //  on pll_config.v content which is generated using
	wire [0:0] clk;             //  icepll -mf pll_config.v -o 21
	pll pll_inst (.clock_in (clk_12mhz),
	              .clock_out(clk),
	              .locked   (pll_locked)); // */


	// Reset Generator
	reg [3:0] resetn_gen = 0;
	reg [0:0] resetn;
	always @(posedge clk) begin
		resetn <= &resetn_gen;
		resetn_gen <= {resetn_gen[2:0], pll_locked};
	end


	// FPS-clock
	localparam FPS = 100;
	localparam FPS_CYCLES = FCLK / FPS;

	reg [0:0]  fps_clk;
	reg [$clog2(FPS_CYCLES):0] fps_clk_counter;
	always @(posedge clk) begin
		if (!resetn) begin
			fps_clk_counter <= FPS_CYCLES-1;
			fps_clk <= 0;
		end else begin
			fps_clk_counter <= fps_clk_counter ? (fps_clk_counter-1) : FPS_CYCLES-1;
			fps_clk <= !fps_clk_counter;
		end
	end


	// ws2812b output
	localparam LEDCOUNT = 36;
	reg  [LEDCOUNT-1:0] red   = 36'b1000_10000001_10000001_10000001_10000001;
	reg  [LEDCOUNT-1:0] green = 36'b1000_00000000_00000000_00000000_00000000;
	reg  [LEDCOUNT-1:0] blue  = 36'b1000_00000000_00000000_00000000_00000000;
	reg  [LEDCOUNT-1:0] red_int;
	reg  [LEDCOUNT-1:0] green_int;
	reg  [LEDCOUNT-1:0] blue_int;
	reg  [5:0] LED_counter = 0;
	wire [0:0] bitstream_read;
	reg  [0:0] bitstream_available = 0;
	reg  [0:0] start = 0;
	reg  [0:0] next_LED = 0;
	reg  [23:0] bitstream;
	// generation of the bitstream
	always @(posedge clk) begin
		if (!resetn) begin
			LED_counter <= 0;
			start <= 0;
			next_LED <= 0;
			bitstream_available <= 0;
		end else begin
			if (bitstream_read || start) begin
				start <= 0;
				bitstream_available <= 0;
				next_LED <= LED_counter > 0;
			end
			if (next_LED) begin
				next_LED <= 0;
				bitstream_available <= 1;
				LED_counter <= LED_counter - 1;
				// rotate internal copies of the respect color
				red_int   <= {red_int[0],   red_int[LEDCOUNT-1:1]};
				green_int <= {green_int[0], green_int[LEDCOUNT-1:1]};
				blue_int  <= {blue_int[0],  blue_int[LEDCOUNT-1:1]};
				// build bitstream for next LED
				bitstream <= {7'b0, green_int[0], 0'b0,
				              7'b0, red_int[0],   0'b0,
				              7'b0, blue_int[0],  0'b0};
			end
			if (fps_clk & !LED_counter) begin
				// after sending all LEDs wait for the fps_clk signal
				LED_counter <= LEDCOUNT;
				start       <= 1;
				red_int     <= red;
				green_int   <= green;
				blue_int    <= blue;
			end
		end
	end
	// actual output of the bitstream
	wire [0:0] ws2812b_data;
	wire [3:0] ws2812b_debug_info;
	ws2812b_out_module #(.CYCLES_SHORT (FCLK/2500000-1), //  ~0.4 us
	                     .CYCLES_LONG  (FCLK/1250000-1), //  ~0.8 us
	                     .CYCLES_RET   (0))              // ~50 us, clk_fps will do this job
	ws2812b_out_int_01 (
                     .clk                 (clk),
                     .resetn              (resetn),
                     .bitstream_available (bitstream_available),
                     .bitstream           (bitstream),
                     .bitstream_read      (bitstream_read),
                     .ws2812b_data        (ws2812b_data),
                     .debug_info          (ws2812b_debug_info)
	                );
	assign pmod1_1 = ws2812b_data;


	reg [2:0] r_addr;
	reg [0:0] do_read = 0;
	always @(posedge clk) begin
		if (!resetn) begin

		end else begin
			if (fps_clk) begin
				do_read <= 1;
			end else if (do_read && r_addr < 4) begin
				if (r_done) begin
					spi_buffer <= {spi_buffer[23:0], r_data};
					r_request  <= 0;
					r_addr     <= r_addr + 1;
				end else if (!r_request) begin
					r_request  <= 1;
					r_address  <= r_addr;
				end
			end else begin
				read         <= 0;
				r_addr       <= 0;
				do_read      <= 0;
				green[ 7: 0] <= spi_buffer[ 7: 0];
				blue [15: 8] <= spi_buffer[15: 8];
				green[23:16] <= spi_buffer[23:15];
				blue [31:24] <= spi_buffer[31:24];
			end
		end
	end


	// instantiation of a SPI slave
	localparam CPOL = 0;
	localparam CPHA = 0;
	localparam LSBFIRST = 0;
	localparam SPI_TIMEOUT_us = 1000; // when to finish a transmitted frame

	wire [7:0] spi_value;
	wire [7:0] spi_debug_info;
	wire [0:0] spi_first_byte;
	wire [0:0] spi_done;
	wire [0:0] spi_timeout;
	reg [31:0] spi_buffer;
	reg  [2:0] write_addr = 0;

	always @(posedge clk) begin
		if (!resetn) begin
			
		end
		else begin
			if (spi_done) begin
				w_data     <= spi_value;
				w_address  <= write_addr;
				w_request  <= 1;
			end else if (w_done) begin
				w_request  <= 0;
				write_addr <= write_addr + 1;
			end else if (spi_timeout) begin
				write_addr <= 0;
			end

/*			if (spi_done) begin
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

	assign {pmod4_10, pmod4_9, pmod4_8, pmod4_7,
	        pmod4_4, pmod4_3, pmod4_2, pmod4_1} = //debug_info;
//	        {spi_debug_info[3:0],
//	        {spi_debug_info[7:4],
//	        {n_mem_CE, n_mem_OE, n_mem_WE, btn2,
	        {w_done, w_request, r_done, r_request,
//	        {w_request, w_started, r_request, r_started,
//	        {hw_n_oe, hw_n_cs, r_started, r_request,
//	        {0, 0, fps_clk, pmod1_1,
//	         r_done || w_done, rpi_ice_mosi, rpi_ice_clk, resetn};
	         pmod1_1, rpi_ice_mosi, rpi_ice_clk, resetn};

	// assign pins to value of leds
	assign {led3, led2, led1} = {rpi_ice_ss, rpi_ice_ss2, fps_clk};
endmodule
