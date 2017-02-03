## POSIX implementation of serial port handling.

import termios, posix, os
include ./common

template checkCallResult(body: untyped): typed =
  ## Wraps a call to a function that returns `-1` on failure, and raises an OSError.
  if body == -1:
    raiseOSError(osLastError())

proc setRawMode(options: var Termios) {.raises: [OSError].} =
  ## Disable echo and set other options required to put the port into "raw" mode.
  options.c_iflag = options.c_iflag and (not (IGNBRK or BRKINT or ICRNL or INLCR or PARMRK or INPCK or ISTRIP or IXON))
  options.c_oflag = options.c_oflag and (not OPOST)
  options.c_lflag = options.c_lflag and (not (ECHO or ECHONL or ICANON or IEXTEN or ISIG))
  options.c_cflag = options.c_cflag and (not (CSIZE or PARENB))

proc openSerialPort*(name: string): SerialPort {.raises: [InvalidPortNameError,OSError].} =
  ## Open the serial port with the given name.
  ##
  ## If the serial port at the given path is not found, a `InvalidPortNameError` will be raised.
  if len(name) < 1:
    raise newException(InvalidPortNameError, "Serial port name is required")

  let h = posix.open(name, O_RDWR or O_NOCTTY or O_NONBLOCK)
  if h == -1:
    raiseOSError(osLastError())

  if isatty(h) != 1:
    raiseOSError(osLastError())

  checkCallResult fcntl(h, F_SETFL, 0)

  var oldPortSettings: Termios
  checkCallResult tcGetAttr(h, addr oldPortSettings)

  result = SerialPort(
    name: name,
    handle: h,
    oldPortSettings: oldPortSettings
  )

  # Flush the buffers of any pre-existing data
  checkCallResult tcflush(h, TCIOFLUSH)

  # Set default baud rate of 9600, input is same as output
  checkCallResult cfsetispeed(addr oldPortSettings, B0)
  checkCallResult cfsetospeed(addr oldPortSettings, B9600)
  setRawMode(oldPortSettings)
  checkCallResult tcSetAttr(h, TCSANOW, addr oldPortSettings)

proc isClosed*(port: SerialPort): bool = port.handle == -1
  ## Determine whether the given port is open or closed.

proc close*(port: SerialPort) =
  ## Close the seial port, restoring its original settings.
  if not port.isClosed:
    checkCallResult tcSetAttr(port.handle, TCSANOW, addr port.oldPortSettings)

    if close(port.handle) == -1:
      raiseOSError(osLastError())

    port.handle = -1

template checkPortIsNotClosed(port: SerialPort) =
  if port.isClosed:
    raise newException(PortClosedError, "Port '" & port.name & "' is closed")

proc `baudRate=`*(port: SerialPort, br: BaudRate) {.raises: [PortClosedError, OSError].} =
  ## Set the baud rate that the serial port operates at.
  checkPortIsNotClosed(port)

  var options: Termios
  checkCallResult tcGetAttr(port.handle, addr options)

  let speed = Speed(br)
  checkCallResult cfSetIspeed(addr options, speed)
  checkCallResult cfSetOspeed(addr options, speed)

  checkCallResult tcSetAttr(port.handle, TCSANOW, addr options)

proc baudRate*(port: SerialPort): BaudRate {.raises: [PortClosedError, OSError].} =
  ## Get the baud rate that the serial port is currently operating at.
  checkPortIsNotClosed(port)

  var options: Termios
  checkCallResult tcGetAttr(port.handle, addr options)
  let speed: Speed = cfGetOspeed(addr options)
  result = BaudRate(speed)

proc `dataBits=`*(port: SerialPort, db: DataBits) {.raises: [PortClosedError, OSError].} =
  ## Set the number of data bits that the serial port operates with.
  checkPortIsNotClosed(port)

  var options: Termios
  checkCallResult tcGetAttr(port.handle, addr options)

  case db
  of DataBits.five:
    options.c_cflag = options.c_cflag or CS5
  of DataBits.six:
    options.c_cflag = options.c_cflag or CS6
  of DataBits.seven:
    options.c_cflag = options.c_cflag or CS7
  of DataBits.eight:
    options.c_cflag = options.c_cflag or CS8

  checkCallResult tcSetAttr(port.handle, TCSANOW, addr options)

proc dataBits*(port: SerialPort): DataBits {.raises: [PortClosedError, OSError].} =
  ## Get the number of data bits that the serial port operates with.
  checkPortIsNotClosed(port)

  var options: Termios
  checkCallResult tcGetAttr(port.handle, addr options)

  if (options.c_cflag and CS8) == CS8:
    result = DataBits.eight
  elif (options.c_cflag and CS7) == CS7:
    result = DataBits.seven
  elif (options.c_cflag and CS6) == CS6:
    result = DataBits.six
  else:
    result = DataBits.five

proc `parity=`*(port: SerialPort, parity: Parity) {.raises: [PortClosedError, OSError].} =
  ## Set the parity that the serial port operates with.
  checkPortIsNotClosed(port)

  var options: Termios
  checkCallResult tcGetAttr(port.handle, addr options)

  case parity
  of Parity.none:
    options.c_cflag = options.c_cflag and (not PARENB)
  of Parity.odd:
    options.c_cflag = options.c_cflag or (PARENB or PARODD)
  of Parity.even:
    options.c_cflag = options.c_cflag and (not PARODD)
    options.c_cflag = options.c_cflag or PARENB

  checkCallResult tcSetAttr(port.handle, TCSANOW, addr options)

proc parity*(port: SerialPort): Parity {.raises: [PortClosedError, OSError].} =
  ## Get the parity that the serial port operates with.
  checkPortIsNotClosed(port)

  var options: Termios
  checkCallResult tcGetAttr(port.handle, addr options)

  if (options.c_cflag and PARENB) == 0:
    result = Parity.none
  elif (options.c_cflag and PARODD) == PARODD:
    result = Parity.odd
  else:
    result = Parity.even

proc `stopBits=`*(port: SerialPort, sb: StopBits) {.raises: [PortClosedError, OSError].} =
  ## Set the number of stop bits that the serial port operates with.
  checkPortIsNotClosed(port)

  var options: Termios
  checkCallResult tcGetAttr(port.handle, addr options)

  case sb
  of StopBits.one:
    options.c_cflag = options.c_cflag and (not CSTOPB)
  of StopBits.onePointFive, StopBits.two:
    options.c_cflag = options.c_cflag or CSTOPB

  checkCallResult tcSetAttr(port.handle, TCSANOW, addr options)

proc stopBits*(port: SerialPort): StopBits {.raises: [PortClosedError, OSError].} =
  ## Get the number of stop bits that the serial port operates with.
  checkPortIsNotClosed(port)

  var options: Termios
  checkCallResult tcGetAttr(port.handle, addr options)

  if (options.c_cflag and CSTOPB) == CSTOPB:
    result = StopBits.two
  else:
    result = StopBits.one

proc write*(port: SerialPort, data: cstring) {.raises: [PortClosedError, OSError], tags: [WriteIOEffect].} =
  ## Write `data` to the serial port. This ensures that all of `data` is written.
  checkPortIsNotClosed(port)

  var
    totalWritten: int = 0
    numWritten: int
  while totalWritten < len(data):
    numWritten = write(port.handle, data[totalWritten].unsafeAddr, len(data) - totalWritten)
    if numWritten == -1:
      raiseOSError(osLastError())
    inc(totalWritten, numWritten)

proc write*(port: SerialPort, data: string) {.raises: [PortClosedError, OSError], tags: WriteIOEffect.} =
  ## Write `data` to the serial port. This ensures that all of `data` is written.
  port.write(data.cstring)
