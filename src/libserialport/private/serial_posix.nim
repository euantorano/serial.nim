# POSIX implementation of serial port handling.

import termios, posix, os

var CRTSCTS {.importc, header: "<termios.h>".}: cuint

proc cfmakeraw*(termios: ptr Termios): void {.importc: "cfmakeraw",
    header: "<termios.h>".}

proc checkCallResult(callResult: int) {.raises: [OSError], inline.} =
  ## Wraps a call to a function that returns `-1` on failure, and raises an OSError.
  if callResult == -1:
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

  # Make reads blocking
  if fcntl(result, F_SETFL, 0) == -1:
    discard close(result)
    raiseOSError(osLastError())

proc convertBaudRate(br: BaudRate): Speed =
  case br
  of BR0:
    result = B0
  of BR50:
    result = B50
  of BR75:
    result = B75
  of BR110:
    result = B110
  of BR134:
    result = B134
  of BR150:
    result = B150
  of BR200:
    result = B200
  of BR300:
    result = B300
  of BR600:
    result = B600
  of BR1200:
    result = B1200
  of BR1800:
    result = B1800
  of BR2400:
    result = B2400
  of BR4800:
    result = B4800
  of BR9600:
    result = B9600
  of BR19200:
    result = B19200
  of BR38400:
    result = B38400

proc setBaudRate(options: ptr Termios, br: BaudRate) {.raises: [OSError].} =
  ## Set the baud rate on the given `Termios` instance.
  let speed = convertBaudRate(br)
  checkCallResult cfSetIspeed(options, speed)
  checkCallResult cfSetOspeed(options, speed)

proc setDataBits(options: var Termios, db: DataBits) =
  ## Set the number of data bits on the given `Termios` instance.
  options.c_cflag = options.c_cflag and (not CSIZE)

  case db
  of DataBits.five:
    options.c_cflag = options.c_cflag or CS5
  of DataBits.six:
    options.c_cflag = options.c_cflag or CS6
  of DataBits.seven:
    options.c_cflag = options.c_cflag or CS7
  of DataBits.eight:
    options.c_cflag = options.c_cflag or CS8

proc setParity(options: var Termios, parity: Parity) {.raises: [ParityUnknownError].} =
  ## Set the parity on the given `Termios` instance.
  case parity
  of Parity.none, Parity.space:
    options.c_cflag = options.c_cflag and (not PARENB)
  of Parity.odd:
    options.c_cflag = options.c_cflag or (PARENB or PARODD)
  of Parity.even:
    options.c_cflag = options.c_cflag or PARENB
    options.c_cflag = options.c_cflag and (not PARODD)
  else:
    raise newException(ParityUnknownError, "Unknown parity: " & $parity)

proc setStopBits(options: var Termios, sb: StopBits) =
  ## Set the number of stop bits on the given `Termios` instance.
  case sb
  of StopBits.one:
    options.c_cflag = options.c_cflag and (not CSTOPB)
  of StopBits.onePointFive, StopBits.two:
    options.c_cflag = options.c_cflag or CSTOPB

proc setHardwareFlowControl(options: var Termios, enabled: bool) =
  ## Set whether to use CTS/RTS flow control.
  if enabled:
    options.c_cflag = options.c_cflag or CRTSCTS
  else:
    options.c_cflag = options.c_cflag and (not CRTSCTS)

proc setSoftwareFlowControl(options: var Termios, enabled: bool) =
  ## Set whether to use XON/XOFF software flow control.
  if enabled:
    options.c_iflag = options.c_cflag or (IXON or IXOFF or IXANY)
  else:
    options.c_iflag = options.c_cflag and (not (IXON or IXOFF or IXANY))

proc openSerialPort*(name: string, baudRate: BaudRate = BaudRate.BR9600,
    dataBits: DataBits = DataBits.eight, parity: Parity = Parity.none,
    stopBits: StopBits = StopBits.one, useHardwareFlowControl: bool = false,
    useSoftwareFlowControl: bool = false): SerialPort {.raises: [InvalidPortNameError, ParityUnknownError, OSError].} =
  ## Open the serial port with the given name.
  ##
  ## If the serial port at the given path is not found, a `InvalidPortNameError` will be raised.
  if len(name) < 1:
    raise newException(InvalidPortNameError, "Serial port name is required")

  let h = openPort(name)

  var oldPortSettings: Termios
  if tcGetAttr(h, addr oldPortSettings) == -1:
    discard close(h)
    raiseOSError(osLastError())

  var newSettings: Termios

  cfmakeraw(addr newSettings)
  newSettings.c_cc[VMIN] = cuchar(1)
  newSettings.c_cc[VTIME] = cuchar(10)
  setBaudRate(addr newSettings, baudRate)
  setDataBits(newSettings, dataBits)
  setStopBits(newSettings, stopBits)
  setParity(newSettings, parity)
  setHardwareFlowControl(newSettings, useHardwareFlowControl)
  setSoftwareFlowControl(newSettings, useSoftwareFlowControl)

  if tcflush(h, TCIOFLUSH) == -1:
    discard close(h)
    raiseOSError(osLastError())

  if tcsetattr(h, TCSANOW, addr newSettings) == -1:
    discard close(h)
    raiseOSError(osLastError())

  result = SerialPort(
    name: name,
    handle: h,
    oldPortSettings: oldPortSettings
  )

proc isClosed*(port: SerialPort): bool = port.handle == -1
  ## Determine whether the given port is open or closed.

proc close*(port: SerialPort) {.raises: [OSError].} =
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

  setDataBits(options, db)

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

proc `parity=`*(port: SerialPort, parity: Parity) {.raises: [PortClosedError, ParityUnknownError, OSError].} =
  ## Set the parity that the serial port operates with.
  checkPortIsNotClosed(port)

  var options: Termios
  checkCallResult tcGetAttr(port.handle, addr options)

  setParity(options, parity)

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

  setStopBits(options, sb)

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

proc `hardwareFlowControl=`*(port: SerialPort, enabled: bool) {.raises: [PortClosedError, OSError].} =
  ## Set whether to use RTS/CTS hardware flow control for sending/receiving data with the serial port.
  checkPortIsNotClosed(port)

  var options: Termios
  checkCallResult tcGetAttr(port.handle, addr options)

  setHardwareFlowControl(options, enabled)

  checkCallResult tcSetAttr(port.handle, TCSANOW, addr options)

proc hardwareFlowControl*(port: SerialPort): bool {.raises: [PortClosedError, OSError].} =
  ## Get whether RTS/CTS hardware flow control is enabled for the serial port.
  checkPortIsNotClosed(port)

  var options: Termios
  checkCallResult tcGetAttr(port.handle, addr options)

  result = (options.c_cflag and CRTSCTS) == CRTSCTS

proc `softwareFlowControl=`*(port: SerialPort, enabled: bool) {.raises: [PortClosedError, OSError].} =
  ## Set whether to use XON/XOFF software flow control for sending/receiving data with the serial port.
  checkPortIsNotClosed(port)

  var options: Termios
  checkCallResult tcGetAttr(port.handle, addr options)

  setSoftwareFlowControl(options, enabled)

  checkCallResult tcSetAttr(port.handle, TCSANOW, addr options)

proc softwareFlowControl*(port: SerialPort): bool {.raises: [PortClosedError, OSError].} =
  ## Get whether XON?XOFF software flow control is enabled for the serial port.
  checkPortIsNotClosed(port)

  var options: Termios
  checkCallResult tcGetAttr(port.handle, addr options)

  result = (options.c_cflag and (IXON or IXOFF or IXANY)) == (IXON or IXOFF or IXANY)

proc write*(port: SerialPort, data: pointer, length: int, timeout: uint = 0): int {.raises: [PortClosedError, PortTimeoutError, OSError], tags: [WriteIOEffect].} =
  ## Write the data in the buffer pointed to by `data` with the given `length` to the serial port.
  checkPortIsNotClosed(port)

  if timeout > 0'u:
    var
      selectSet: TFdSet
      timer: Timeval
    FD_ZERO(selectSet)
    FD_SET(port.handle, selectSet)

    let selected = select(cint(port.handle + 1), nil, addr selectSet, nil, addr timer)

    case selected
    of -1:
      raiseOSError(osLastError())
    of 0:
      raise newException(PortTimeoutError, "Write timed out after " & $timeout & " seconds")
    else:
      result = write(port.handle, data, length)
  else:
    result = write(port.handle, data, length)
    if result == -1:
      raiseOSError(osLastError())

proc write*(port: SerialPort, data: cstring, timeout: uint = 0) {.raises: [PortClosedError, PortTimeoutError, OSError], tags: [WriteIOEffect].} =
  ## Write `data` to the serial port. This ensures that all of `data` is written.
  checkPortIsNotClosed(port)

  var
    totalWritten: int = 0
    numWritten: int

  if timeout > 0'u:
    var
      selectSet: TFdSet
      timer: Timeval
      selected: cint
    FD_ZERO(selectSet)
    FD_SET(port.handle, selectSet)

    while totalWritten < len(data):
      selected = select(cint(port.handle + 1), nil, addr selectSet, nil, addr timer)

      case selected
      of -1:
        raiseOSError(osLastError())
      of 0:
        raise newException(PortTimeoutError, "Write timed out after " & $timeout & " seconds")
      else:
        numWritten = write(port.handle, data[totalWritten].unsafeAddr, len(data) - totalWritten)
        inc(totalWritten, numWritten)
  else:
    while totalWritten < len(data):
      numWritten = write(port.handle, data[totalWritten].unsafeAddr, len(data) - totalWritten)
      if numWritten == -1:
        raiseOSError(osLastError())
      inc(totalWritten, numWritten)

proc rawRead(handle: FileHandle, data: pointer, size: int): int {.inline, raises: [OSError], tags: [ReadIOEffect].} =
  ## Raw read form the given file handle, without any timeout.
  result = read(handle, data, size)
  if result == -1:
    raiseOSError(osLastError())

proc read*(port: SerialPort, data: pointer, size: int, timeout: uint = 0): int
  {.raises: [PortClosedError, PortTimeoutError, OSError], tags: [ReadIOEffect].} =
  ## Read from the serial port into the buffer pointed to by `data`, with buffer length `size`.
  ##
  ## This will return the number of bytes received, as it does not guarantee that the buffer will be filled completely.
  ##
  ## The read will time out after `timeout` seconds if no data is received in that time.
  ## To disable timeouts, pass `0` as the timeout parameter. When timeouts are disabled, this will block until at least 1 byte of data is received.
  checkPortIsNotClosed(port)

  if timeout > 0'u:
    var
      selectSet: TFdSet
      timer: Timeval
    FD_ZERO(selectSet)
    FD_SET(port.handle, selectSet)

    timer.tv_sec = int(timeout)

    let selected = select(cint(port.handle + 1), addr selectSet, nil, nil, addr timer)

    case selected
    of -1:
      raiseOSError(osLastError())
    of 0:
      raise newException(PortTimeoutError, "Read timed out after " & $timeout & " seconds")
    else:
      result = rawRead(port.handle, data, size)
  else:
    result = rawRead(port.handle, data, size)
