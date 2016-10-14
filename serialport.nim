## A library to work with serial ports using pure Nim.

type
  Parity* {.pure.} = enum
    ## Allowable parities for the serial port.
    none, odd, even

  BaudRate* = enum
    ## Serial baud rates.
    BR0 = 0,
    BR50 = 50,
    BR75 = 75,
    BR110 = 110,
    BR134 = 134,
    BR150 = 150,
    BR200 = 200,
    BR300 = 300,
    BR600 = 600,
    BR1200 = 1200,
    BR1800 = 1800,
    BR2400 = 2400,
    BR4800 = 4800,
    BR9600 = 9600,
    BR19200 = 19_200,
    BR38400 = 38_400,
    BR57600 = 57_600,
    BR115200 = 115_200,
    BR230400 = 230_400,

  DataBits* {.pure.} = enum
    ## The standard length of data bits per byte for the serial port.
    five = 5,
    six = 6,
    seven = 7
    eight = 8

  StopBits* {.pure.} = enum
    ## The standard number of stopbits per byte for the serial port.
    none = 0,
    one = 1,
    onePointFive = 1.5,
    two = 2

  SerialPortObj = object
    ## Represents a serial port.
    name: string,
    readTimeout: int,
    writeTimeout: int,

    when defined(windows):
      handle: Handle
    else:
      handle: int

  SerialPort* = ref SerialPortObj
    ## Represents a serial port.

const
  defaultParity: Parity = Parity.none
  defaultBaudRate: BaudRate = BD9600
  defaultDataBits: DataBits = DataBits.eight
  defaultStopBits: StopBits = StopBits.none

include private/list_serialports
