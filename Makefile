
ifeq ($(shell bash -c 'type -p icoprog'),)
#SSH_RASPI ?= ssh pi@raspi
SSH_RASPI ?= ssh pi@10.42.0.187
else
SSH_RASPI ?= sh -c
endif

FILE=top
MODULE=top
DEPS=spi.v ws2812b_out.v ws2812b_out_parallel.v memory.v bram.v clock.v
PLL=pll_config.v

help:
	@echo
	@echo "make top.blif      run synthesis, generate BLIF netlist"
	@echo "make top.asc       run place and route, generate IceStorm ASCII file"
	@echo "make top.bin       run timing analysis, generate iCE40 BIN file"
	@echo
	@echo "make prog_sram         FPGA SRAM programming, (re)starts FPGA from SRAM"
	@echo "make prog_flash        serial flash programming, does not touch FPGA"
	@echo "make prog_erase        erase first flash block"
	@echo
	@echo "make reset_halt        stop FPGA and keep in reset"
	@echo "make reset_boot        (re)start FPGA from serial flash"
	@echo
	@echo "make show FILE=top MODULE=mod"
	@echo "                       show diagram for module mod within top.v"
	@echo "make sim FILE=top      run test bench top_tb.v on top.v"
	@echo "make verify            formaly verify project"
	@echo "make verify_module FILE=spi MODULE=spi_slave"
	@echo "                       formaly verify module spi_slave in spi.v"
	@echo
	@echo "make clean             remove output files"
	@echo
	@echo "make set pin=40 value=1  set raspbery Pi pin 40 to 1"
	@echo "make send hex=\"FF FF\"  send list of bytes to icoboard over spi"
	@echo


$(FILE).blif: $(FILE).v $(DEPS) $(PLL)
	yosys -p 'synth_ice40 -blif $(FILE).blif' $(FILE).v $(DEPS) $(PLL) > yosys.out
	sed "/Warning/p" -n < yosys.out > yosys.warnings
	cat yosys.warnings

$(FILE).asc: $(FILE).blif icoboard.pcf
	arachne-pnr -d 8k -p icoboard.pcf -o $(FILE).asc $(FILE).blif

$(FILE).bin: $(FILE).asc
	icetime -d hx8k -c 38 $(FILE).asc
	icepack $(FILE).asc $(FILE).bin

prog_sram: $(FILE).bin
	cat yosys.warnings
	$(SSH_RASPI) 'icoprog -p' < $(FILE).bin

prog_flash: $(FILE).bin
	$(SSH_RASPI) 'icoprog -f' < $(FILE).bin

prog_erase:
	$(SSH_RASPI) 'icoprog -e'

reset_halt:
	$(SSH_RASPI) 'icoprog -R'

reset_boot:
	$(SSH_RASPI) 'icoprog -b'

show:    $(FILE).v
	yosys -p 'show -stretch $(MODULE)' $(FILE).v
#	yosys -p 'show -stretch $(FILE)' spi.v
#	yosys -p 'show -stretch $(FILE)' ws2812b_out.v
#	yosys -p 'show -format ps -viewer gv' $(FILE).v

sim: $(FILE)_tb.v $(FILE).v $(DEPS)
	iverilog -s testbench -o testbench.vvp $(FILE)_tb.v $(FILE).v $(DEPS)
	vvp testbench.vvp -lxt2 > $(FILE)_tb.out
	cat $(FILE)_tb.out
	gtkwave testbench.vcd $(FILE)_tb.gtkw &

verify_module: $(FILE).v $(DEPS)
	yosys -ql $(FILE).yslog \
	      -p 'read_verilog -formal $(FILE).v $(DEPS)' \
	      -p 'prep -top $(MODULE) -nordff' \
	      -p 'write_smt2 $(FILE).smt2'
	yosys-smtbmc --dump-vcd $(FILE).vcd -c $(FILE).smt2 && \
	yosys-smtbmc --dump-vcd $(FILE).vcd -t 30 $(FILE).smt2 && \
	yosys-smtbmc --dump-vcd $(FILE).vcd -it 30 $(FILE).smt2 || \
	gtkwave $(FILE).vcd

verify:
	make verify_module FILE=spi MODULE=spi_slave

spisrv: spi_server.c
	$(SSH_RASPI) "g++ -lwiringPi -o spi_server -x c++ -" < spi_server.c
	$(SSH_RASPI) "./spi_server"

spi:
	$(SSH_RASPI) "./spi_server"

# example call: make send hex="FF FF"
send:
	cat spi_tx.py | $(SSH_RASPI) python - $(hex)

# example call: make set pin=40 value=1
set:
	cat gpio_set.py | $(SSH_RASPI) python - $(pin) $(value)

clean:
	rm $(FILE).blif $(FILE).asc $(FILE).bin $(FILE).smt2 $(FILE).vdc $(FILE).yslog

.PHONY: prog_sram prog_flash reset_halt reset_boot clean

