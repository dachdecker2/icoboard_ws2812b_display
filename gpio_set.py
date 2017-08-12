
import RPi.GPIO as GPIO
import sys

def set(pin, state):
    GPIO.setwarnings(False)
    GPIO.setmode(GPIO.BOARD)
    try:
        GPIO.setup(pin, GPIO.OUT, initial=[GPIO.LOW, GPIO.HIGH][state])
        print 'set pin %s to %s' % (pin, state)
    except ValueError:
        print 'unable to set pin %s to %s' % (pin, state)


if __name__ == '__main__':
    if len(sys.argv) == 3:
        pin, state = map(lambda p: int(p, 10), sys.argv[1:])
        set(pin, state)

    else:
        print '%s pin state' % sys.argv[0]
        print '   sets pin to state'
        print '      pin number (RasPI board numbering)'
        print '      state: {0, 1}'
