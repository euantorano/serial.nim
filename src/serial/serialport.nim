## Methods to open, read from and write to serial ports.

when defined(windows):
  include ./private/serialport/serialport_windows
elif defined(posix):
  include ./private/serialport/serialport_posix
else:
  {.error: "Serial port handling not implemented for your platform".}

proc read*(port: SerialPort, buff: var string): int32 =
  ## Read from the serial port into the buffer `buff`. This will return the actual number of bytes that were received.
  if len(buff) == 0:
    return 0

  result = port.read(addr buff[0], int32(len(buff)))

proc read*(port: AsyncSerialPort, buff: FutureVar[string]): Future[int32] {.async.} =
  ## Read from the serial port into the buffer `buff`. This will return the actual number of bytes that were received.
  var mbuff = buff.mget()

  if len(mbuff) == 0:
    return 0

  result = await port.read(addr mbuff[0], int32(len(mbuff)))

  if result == 0:
    mbuff.setLen(0)

  buff.complete(mbuff)

proc read*(port: SerialPort | AsyncSerialPort, size: int32): Future[string] {.multisync.} =
  ## Read at most the specified `size` number of bytes from the serial port and return it as a string.
  if size == 0:
    return ""

  var buff = newString(size)

  let numRead = await port.read(addr buff[0], size)

  if numRead == 0:
    result = ""
  else:
    result = buff[0 ..< numRead]

proc write*(port: SerialPort | AsyncSerialPort, buff: string): Future[int32] {.multisync.} =
  ## Write the data to the serialport `port` from the buffer `buff`. This will return the number of bytes that were written.
  if len(buff) == 0:
    return 0

  var copy = buff
  result = await port.write(addr copy[0], int32(len(copy)))
