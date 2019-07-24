## Common types shared by all serialport implementations.

import events

const
  TIMEOUT_INFINITE* = -1'i32
  InvalidFileHandle* = FileHandle(-1)

type
  Parity* {.pure.} = enum
    None = 0,
    Odd = 1,
    Even = 2,
    Mark = 3,
    Space = 4

  Handshake* {.pure.} = enum
    None,
      ## No flow control.
    XOnXOff,
      ## Software flow control (XON/XOFF)
    RequestToSend,
      ## Hardware flow control (RTS/CTS)
    RequestToSendXOnXOff
      ## Both hardware flow contorl and software flow control (XON/XOFF and RTS/CTS)

  StopBits* {.pure.} = enum
    One = 1,
    Two = 2,
    OnePointFive = 3

  InvalidSerialPortError* = object of Exception

  TimeoutError* = object of IOError

  InvalidSerialPortStateError* = object of IOError

  InvalidBaudRateError* = object of Exception

  InvalidDataBitsError* = object of Exception

  InvalidStopBitsError* = object of Exception

  ReceivedError* {.pure.} = enum
    ## Types of error detected by the operating system whilst reading from/writing to a serial port.
    Framing = "The hardware detected a framing error.",
    Overrun = "A character-buffer overrun has occurred. The next character is lost.",
    ReceiveOverflow = "An input buffer overflow has occurred. There is either no room in the input buffer, or a character was received after the end-of-file (EOF) character.",
    Parity = "The hardware detected a parity error."
