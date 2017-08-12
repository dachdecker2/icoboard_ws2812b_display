import spidev
import RPi.GPIO as GPIO
import time
import sys

SPI_CLK_SPEED = 1000
SPI_SELECT = 40
SPI_DEVICE = (0, 0)


def spi_init():
    device = spidev.SpiDev()
    device.open(*SPI_DEVICE)
    device.max_speed_hz = SPI_CLK_SPEED

    GPIO.setwarnings(False)
    GPIO.setmode(GPIO.BOARD)
    GPIO.setup(SPI_SELECT, GPIO.OUT, initial=GPIO.HIGH)

    return device


def spi_send(dev, value):

    GPIO.output(SPI_SELECT, GPIO.LOW)
    dev.xfer(value)
    GPIO.output(SPI_SELECT, GPIO.HIGH)


if __name__ == '__main__':
    if len(sys.argv) > 1:
        paras = map(lambda p: int(p, 16), sys.argv[1:])
        dev = spi_init()
        spi_send(dev, paras)
        print 'sent %s' % paras

    else:
        main()
