`timescale 1us/100ns

module testbench ();

	initial begin
		$dumpfile("testbench.vcd");
		$dumpvars(0, testbench);
	end

	reg [0:0] clk    = 0;
	reg [0:0] resetn = 0;
	initial begin
		// pull reset if available
		resetn = 0;
		repeat(10) #1 clk = !clk;
		// release reset if available
		resetn = 1;
		forever #1 clk = !clk;
	end

	reg [0:0] SPI_CS = 1;
	reg [0:0] SPI_CLK = 0;
	reg [0:0] SPI_MOSI = 0;

	wire [0:0] first_byte;
	reg  [0:0] first_byte_expected;
	wire [7:0] read_value;
	reg  [7:0] read_value_expected;
	wire [0:0] done;


	localparam FCLK = 100;
	localparam BAUDRATE = 15;
	localparam HALFBITTIME = FCLK / BAUDRATE / 2;

	task send_byte;
		input [7:0] byte;
		input [3:0] bitcount;
		integer i;
//		for(i=0; i<8; i=i+1)
		begin
			for(i=0; i<bitcount; i=i+1) begin
				             SPI_MOSI <= byte[7-i];
				#HALFBITTIME SPI_CLK <= 1;
				#HALFBITTIME SPI_CLK <= 0;
			end
			SPI_MOSI <= 0;
			#HALFBITTIME;
		end
	endtask


	// CPOL == 0: clock state while idle is low  ("inactive")
	// CPOL == 1: clock state while idle is high ("inactive")
	parameter CPOL = 0;
	// CPHA == 0: write on clock deactivation, sample on clock activation
	// CPHA == 1: write on clock activation, sample on clock deactivation
	parameter CPHA = 0;
	parameter LSBFIRST = 1;

	spi_slave #(.CPOL           (CPOL),
	            .CPHA           (CPHA),
	            .LSBFIRST       (LSBFIRST),
	            .TIMEOUT__NOT_CS(0),
	            .TIMEOUT_CYCLES (1))
	DUT (.clk             (clk),
	     .resetn          (resetn),
	     .spi_clk         (SPI_CLK),
	     .spi_mosi        (SPI_MOSI),
	     .spi_cs          (SPI_CS),
	     .read_value      (read_value),
	     .done            (done),
	     .timeout_expired (),
	     .first_byte      (first_byte),
	     .debug_info      ()
	     );

	initial begin
		SPI_CS = 1;

		#20 SPI_CS <= 0;
		read_value_expected <= 8'h81; first_byte_expected <= 1; #1 send_byte(read_value_expected, 8);
		read_value_expected <= "@";   first_byte_expected <= 0; #1 send_byte(read_value_expected, 8);
		read_value_expected <= "A";   first_byte_expected <= 0; #1 send_byte(read_value_expected, 8);
		read_value_expected <= "B";   first_byte_expected <= 0; #1 send_byte(read_value_expected, 8);
		read_value_expected <= "C";   first_byte_expected <= 0; #1 send_byte(read_value_expected, 8);
		#1 SPI_CS <= 1;

		// this is an incomplete transmission
		// "done" should not get 1, if it gets 1, the test should fail, since MOSI was inverted
		#20 SPI_CS <= 0;
		read_value_expected <= "0";   first_byte_expected <= 1; #1 send_byte(~read_value_expected, 7);
		#1 SPI_CS <= 1;

		// the incomplete transmission shall not have any consequences for following receptions
		#20 SPI_CS <= 0;
		read_value_expected <= "0";   first_byte_expected <= 1; #1 send_byte(read_value_expected, 8);
		read_value_expected <= "-";   first_byte_expected <= 0; #1 send_byte(read_value_expected, 8);
		#1 SPI_CS <= 1;

		#100 $finish;
	end

	always @(posedge done) begin
		if (read_value == read_value_expected)
			$display("pass: value: %c, is_first_byte: %b", read_value, first_byte);
		else
			$display("fail: value(expected): %c / 0x%X (%c / 0x%X), first_byte: %b(%b)", read_value, read_value, read_value_expected, read_value_expected, first_byte, first_byte_expected);
	end

endmodule
