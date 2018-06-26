## Methods to open, read from and write to serial ports.

when defined(windows):
  include ./private/serialport/serialport_windows
elif defined(posix):
  include ./private/serialport/serialport_posix
else:
  {.error: "Serial port handling not implemented for your platform".}

proc read*(port: SerialPort, buff: var string): int32 =
  ## Read from the serial port into the buffer `buff`. This will return the actual number of bytes that were received.
  if isNil(buff) or len(buff) == 0:
    return 0

  result = port.read(addr buff[0], int32(len(buff)))

proc write*(port: SerialPort, buff: var string): int32 =
  ## Write the data to the serialport `port` from the buffer `buff`. This will return the number of bytes that were written.
  if isNil(buff) or len(buff) == 0:
    return 0

  result = port.write(addr buff[0], int32(len(buff)))
