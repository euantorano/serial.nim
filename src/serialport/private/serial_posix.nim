## POSIX implementation of serial port handling.

import termios, posix, os
include ./common

var
  TIOCEXCL* {.importc, header: "<termios.h>".}: cuint

proc cfmakeraw*(termios: ptr Termios): void {.importc: "cfmakeraw",
    header: "<termios.h>".}

template checkCallResult(body: untyped): typed =
  ## Wraps a call to a function that returns `-1` on failure, and raises an OSError.
  if body == -1:
    raiseOSError(osLastError())

proc openPort(path: string): FileHandle {.raises: [OSError].} =
  ## Open the serial port device file at `path`

  # Open the file as read/write
  # Use O_NOCTTY as we don't want to be the "controlling terminal" for the port
  # Use O_NDELAY as we don't care what state the DCD line is in.
  result = open(path, O_RDWR or O_NOCTTY or O_NONBLOCK)
  if result == -1:
    raiseOSError(osLastError())

  # Check the opened port is a serial port
  if isatty(result) != 1:
    discard close(result)
    raiseOSError(osLastError())

  # Prevent other `open()` calls with the same file except by root-owned processes
  checkCallResult ioctl(result, TIOCEXCL)

  # Make reads blocking
  checkCallResult fcntl(result, F_SETFL, 0)

proc setBaudRate(options: ptr Termios, br: BaudRate) {.raises: [OSError].} =
  ## Set the baud rate on the given `Termios` instance.
  let speed = Speed(br)
  checkCallResult cfSetIspeed(options, speed)
  checkCallResult cfSetOspeed(options, speed)

proc setDataBits(options: ptr Termios, db: DataBits) =
  ## Set the number of data bits on the given `Termios` instance.
  case db
  of DataBits.five:
    options.c_cflag = options.c_cflag or CS5
  of DataBits.six:
    options.c_cflag = options.c_cflag or CS6
  of DataBits.seven:
    options.c_cflag = options.c_cflag or CS7
  of DataBits.eight:
    options.c_cflag = options.c_cflag or CS8

proc setParity(options: ptr Termios, parity: Parity) =
  ## Set the parity on the given `Termios` instance.
  case parity
  of Parity.none:
    options.c_cflag = options.c_cflag and (not PARENB)
  of Parity.odd:
    options.c_cflag = options.c_cflag or (PARENB or PARODD)
  of Parity.even:
    options.c_cflag = options.c_cflag and (not PARODD)
    options.c_cflag = options.c_cflag or PARENB

proc setStopBits(options: ptr Termios, sb: StopBits) =
  ## Set the number of stop bits on the given `Termios` instance.
  case sb
  of StopBits.one:
    options.c_cflag = options.c_cflag and (not CSTOPB)
  of StopBits.onePointFive, StopBits.two:
    options.c_cflag = options.c_cflag or CSTOPB

proc openSerialPort*(name: string, baudRate: BaudRate = BaudRate.BR9600,
    dataBits: DataBits = DataBits.eight, parity: Parity = Parity.none,
    stopBits: StopBits = StopBits.one): SerialPort {.raises: [InvalidPortNameError,OSError].} =
  ## Open the serial port with the given name.
  ##
  ## If the serial port at the given path is not found, a `InvalidPortNameError` will be raised.
  if len(name) < 1:
    raise newException(InvalidPortNameError, "Serial port name is required")

  let h = openPort(name)

  var oldPortSettings: Termios
  checkCallResult tcGetAttr(h, addr oldPortSettings)

  var newSettings: Termios = oldPortSettings

  cfmakeraw(addr newSettings)
  newSettings.c_cc[VMIN] = cuchar(1)
  newSettings.c_cc[VTIME] = cuchar(10)
  setBaudRate(addr newSettings, baudRate)
  setDataBits(addr newSettings, dataBits)
  setParity(addr newSettings, parity)

  checkCallResult tcflush(h, TCIOFLUSH)
  checkCallResult tcsetattr(h, TCSANOW, addr newSettings)

  result = SerialPort(
    name: name,
    handle: h,
    oldPortSettings: oldPortSettings
  )

proc isClosed*(port: SerialPort): bool = port.handle == -1
  ## Determine whether the given port is open or closed.

proc close*(port: SerialPort) =
  ## Close the seial port, restoring its original settings.
  if not port.isClosed:
    checkCallResult tcdrain(port.handle)

    checkCallResult tcSetAttr(port.handle, TCSANOW, addr port.oldPortSettings)

    checkCallResult close(port.handle)

    port.handle = -1

template checkPortIsNotClosed(port: SerialPort) =
  if port.isClosed:
    raise newException(PortClosedError, "Port '" & port.name & "' is closed")

proc `baudRate=`*(port: SerialPort, br: BaudRate) {.raises: [PortClosedError, OSError].} =
  ## Set the baud rate that the serial port operates at.
  checkPortIsNotClosed(port)

  var options: Termios
  checkCallResult tcGetAttr(port.handle, addr options)

  setBaudRate(addr options, br)

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

  setDataBits(addr options, db)

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

  setParity(addr options, parity)

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

  setStopBits(addr options, sb)

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

proc read*(port: SerialPort, data: pointer, size: int, timeoutSeconds: int = 5): int {.raises: [PortClosedError, PortReadTimeoutError, OSError], tags: ReadIOEffect.} =
  ## Read from the serial port into the buffer pointed to by `data`, with buffer length `size`.
  ##
  ## This will return the number of bytes received, as it does not guarantee that the buffer will be filled completely.
  checkPortIsNotClosed(port)

  var
    selectSet: TFdSet
    timeout: Timeval
  FD_ZERO(selectSet)
  FD_SET(port.handle, selectSet)

  timeout.tv_sec = timeoutSeconds

  let selected = select(cint(port.handle), addr selectSet, nil, nil, addr timeout)

  case selected
  of -1:
    raiseOSError(osLastError())
  of 0:
    raise newException(PortReadTimeoutError, "Read timed out after " & $timeoutSeconds & " seconds")
  else:
    result = read(port.handle, data, size)
    if result == -1:
      raiseOSError(osLastError())
