## Common definitions shared between platform specific implementations.

when defined(posix):
  import termios

type
  Parity* {.pure.} = enum
    ## Allowable parities for the serial port.
    none, odd, even, space

  BaudRate* {.pure.} = enum
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
    BR19200 = 19200,
    BR38400 = 38400

  DataBits* {.pure.} = enum
    ## The standard length of data bits per byte for the serial port.
    five,
    six,
    seven,
    eight

  StopBits* {.pure.} = enum
    ## The standard number of stopbits per byte for the serial port.
    one,
    onePointFive,
    two

  SerialPortObj = object
    ## Represents a serial port.
    name: string
    when defined(posix):
      handle: FileHandle
      oldPortSettings: Termios

  FlowControlSettings* = tuple[cts: bool, rts: bool]
    ## Flow control settings for use with a serial port.

  SerialPort* = ref SerialPortObj not nil
    ## Represents a serial port.

  SerialPortError* = object of Exception
    ## Base error type for errors raised by the serialport module.

  InvalidPortNameError* = object of SerialPortError
    ## Raised if an invalid port name is provided when opening a serial port with `openSerialPort`.

  PortClosedError* = object of SerialPortError
    ## Raised when an operation is attempted on a port that is closed.

  PortReadError* = object of SerialPortError
    ## Raised when an error occurs whilst reading a serial port.

  PortReadTimeoutError* = object of SerialPortError
    ## Raised when reading from a serial port times out.

proc `$`*(port: Serialport): string = port.name
  ## Convert a port to a string, using the port's name.
