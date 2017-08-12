import spidev
import RPi.GPIO as GPIO
import time

SPI_CLK_SPEED = 1000
SPI_SELECT = 40
SPI_DEVICE = (0, 0)


def spi_init():

        device = spidev.SpiDev()
        device.open(*SPI_DEVICE)
        device.max_speed_hz = SPI_CLK_SPEED

        GPIO.setmode(GPIO.BOARD)
        GPIO.setup(SPI_SELECT, GPIO.OUT, initial=GPIO.HIGH)

        return device


def spi_send(dev, value):

        GPIO.output(SPI_SELECT, GPIO.LOW)
        dev.xfer(value)
        GPIO.output(SPI_SELECT, GPIO.HIGH)


def __main__():

        dev = spi_init()

        spi_send(dev, [255 for i in range(4)])
        time.sleep(2)
        spi_send(dev, [0 for i in range(4)])
        time.sleep(2)
        spi_send(dev, [2 for i in range(4)])
        time.sleep(2)
        spi_send(dev, [4 for i in range(4)])


__main__()

