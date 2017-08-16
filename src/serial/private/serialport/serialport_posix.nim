## Serial port handling for POSIX.

import ./serialport_common

export serialport_common

import os, posix, posix/termios

var
  CRTSCTS {.importc, header: "<termios.h>".}: cuint
  TIOCM_DTR {.importc, header: "<termios.h>".}: cint
  TIOCM_RTS {.importc, header: "<termios.h>".}: cint
  TIOCM_CAR {.importc, header: "<termios.h>".}: cint
  TIOCM_CTS {.importc, header: "<termios.h>".}: cint
  TIOCM_LE {.importc, header: "<termios.h>".}: cint
  TIOCM_RNG {.importc, header: "<termios.h>".}: cint
  TIOCMGET {.importc, header: "<termios.h>".}: cint
  TIOCMBIC {.importc, header: "<termios.h>".}: cint
  TIOCMBIS {.importc, header: "<termios.h>".}: cint

type
  SerialPortBase[THandle] = ref object of RootObj
    name*: string
    handshake: Handshake
    handle: FileHandle
    readTimeout: int32
    writeTimeout: int32

  SerialPort* = ref object of SerialPortBase[FileHandle]
    ## A serial port type used to read from and write to serial ports.

proc ioctl(handle: cint, command: cint, arg: ptr cint): cint {.importc, header: "<sys/ioctl.h>".}

proc existsPort(path: string): bool =
  var res: Stat
  result = stat(path, res) >= 0 and S_ISCHR(res.st_mode)

proc newSerialPort*(portName: string): SerialPort =
  ## Initialise a new serial port, ready to open.
  if not existsPort(portName):
    raise newException(InvalidSerialPortError, "Serialport path '" & portName & "' does not exist or is not a character device")

  result = SerialPort(
      name: portName,
      handle: InvalidFileHandle
  )

proc isOpen*(port: SerialPort): bool =
  ## Check whether the serial port is currently open.
  result = port.handle != InvalidFileHandle

proc getTimeouts*(port: SerialPort): tuple[readTimeout: int32, writeTimeout: int32] =
  ## Get the read and write timeouts for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get timeouts whilst the serial port is closed")

  result = (readTimeout: port.readTimeout, writeTimeout: port.writeTimeout)

proc setTimeouts*(port: SerialPort, readTimeout: int32, writeTimeout: int32) =
  ## Set the read and write timeouts for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot set timeouts whilst the serial port is closed")

  port.readTimeout = readTimeout
  port.writeTimeout = writeTimeout

proc isCarrierHolding*(port: SerialPort): bool =
  ## Check whether the carrier signal is currently active.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot check the carrier signal whilst the serial port is closed")

  var flag: cint
  if ioctl(port.handle, TIOCMGET, addr flag) == -1:
    raiseOSError(osLastError())

  result = (flag and TIOCM_CAR) == TIOCM_CAR

proc isCtsHolding*(port: SerialPort): bool =
  ## Check whether the clear to send signal is currently active.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot check the clear to send signal whilst the serial port is closed")

  var flag: cint
  if ioctl(port.handle, TIOCMGET, addr flag) == -1:
    raiseOSError(osLastError())

  result = (flag and TIOCM_CTS) == TIOCM_CTS

proc isDsrHolding*(port: SerialPort): bool =
  ## Check whether the data set ready signal is currently active.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot check the data set ready signal whilst the serial port is closed")

  var flag: cint
  if ioctl(port.handle, TIOCMGET, addr flag) == -1:
    raiseOSError(osLastError())

  result = (flag and TIOCM_LE) == TIOCM_LE

proc isRingHolding*(port: SerialPort): bool =
  ## Check whether the ring signal is currently active.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot check the ring signal whilst the serial port is closed")

  var flag: cint
  if ioctl(port.handle, TIOCMGET, addr flag) == -1:
    raiseOSError(osLastError())

  result = (flag and TIOCM_RNG) == TIOCM_RNG

proc setStopBits(settings: var Termios, stopBits: StopBits) =
  case stopBits
  of StopBits.One:
    settings.c_cflag = settings.c_cflag and (not CSTOPB)
  of StopBits.Two, StopBits.OnePointFive:
    settings.c_cflag = settings.c_cflag or CSTOPB

proc `stopBits=`*(port: SerialPort, stopBits: StopBits) =
  ## Set the stop bits for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot set the stop bits whilst the serial port is closed")

  var settings: Termios
  if tcGetAttr(port.handle, addr settings) == -1:
    raiseOSError(osLastError())

  setStopBits(settings, stopBits)

  if tcSetAttr(port.handle, TCSANOW, addr settings) == -1:
    raiseOSError(osLastError())

proc stopBits*(port: SerialPort): StopBits =
  ## Get the current stop bits for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the stop bits whilst the serial port is closed")

  var settings: Termios
  if tcGetAttr(port.handle, addr settings) == -1:
    raiseOSError(osLastError())

  if (settings.c_cflag and CSTOPB) == CSTOPB:
    result = StopBits.Two
  else:
    result = StopBits.One

proc setDataBits(settings: var Termios, dataBits: byte) =
  settings.c_cflag = settings.c_cflag and (not CSIZE)

  case dataBits
  of 5:
    settings.c_cflag = settings.c_cflag or CS5
  of 6:
    settings.c_cflag = settings.c_cflag or CS6
  of 7:
    settings.c_cflag = settings.c_cflag or CS7
  of 8:
    settings.c_cflag = settings.c_cflag or CS8
  else:
    raise newException(InvalidDataBitsError, "Invalid number of data bits: '" & $dataBits & "'")

proc `dataBits=`*(port: SerialPort, dataBits: byte) =
  ## Set the number of data bits for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot set the data bits whilst the serial port is closed")

  var settings: Termios
  if tcGetAttr(port.handle, addr settings) == -1:
    raiseOSError(osLastError())

  setDataBits(settings, dataBits)

  if tcSetAttr(port.handle, TCSANOW, addr settings) == -1:
    raiseOSError(osLastError())

proc dataBits*(port: SerialPort): byte =
  ## Get the number of data bits for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the data bits whilst the serial port is closed")

  var settings: Termios
  if tcGetAttr(port.handle, addr settings) == -1:
    raiseOSError(osLastError())

  if (settings.c_cflag and CS8) == CS8:
    result = 8
  elif (settings.c_cflag and CS7) == CS7:
    result = 7
  elif (settings.c_cflag and CS6) == CS6:
    result = 6
  else:
    result = 5

proc setSpeed(settings: ptr Termios, speed: int32) =
  var baud: Speed
  case speed
  of 0:
    baud = B0
  of 50:
    baud = B50
  of 75:
    baud = B75
  of 110:
    baud = B110
  of 134:
    baud = B134
  of 150:
    baud = B150
  of 200:
    baud = B200
  of 300:
    baud = B300
  of 600:
    baud = B600
  of 1200:
    baud = B1200
  of 1800:
    baud = B1800
  of 2400:
    baud = B2400
  of 4800:
    baud = B4800
  of 9600:
    baud = B9600
  of 19200:
    baud = B19200
  of 38400:
    baud = B38400
  else:
    raise newException(InvalidBaudRateError, "Unsupported baud rate '" & $speed & "'")

  if cfSetIspeed(settings, baud) == -1:
    raiseOSError(osLastError())

  if cfSetOspeed(settings, baud) == -1:
    raiseOSError(osLastError())

proc `baudRate=`*(port: SerialPort, baudRate: int32) =
  ## Set the baud rate for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot set the baud rate whilst the serial port is closed")

  var settings: Termios
  if tcGetAttr(port.handle, addr settings) == -1:
    raiseOSError(osLastError())

  setSpeed(addr settings, baudRate)

  if tcSetAttr(port.handle, TCSANOW, addr settings) == -1:
    raiseOSError(osLastError())

proc baudRate*(port: SerialPort): int32 =
  ## Get the current baud rate for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the baud rate whilst the serial port is closed")

  var settings: Termios
  if tcGetAttr(port.handle, addr settings) == -1:
    raiseOSError(osLastError())

  let speed: Speed = cfGetOspeed(addr settings)

  if speed == B0:
    result = 0
  elif speed == B50:
    result = 50
  elif speed == B75:
    result = 75
  elif speed == B110:
    result = 110
  elif speed == B134:
    result = 134
  elif speed == B150:
    result = 150
  elif speed == B200:
    result = 200
  elif speed == B300:
    result = 300
  elif speed == B600:
    result = 600
  elif speed == B1200:
    result = 1200
  elif speed == B1800:
    result = 1800
  elif speed == B2400:
    result = 2400
  elif speed == B4800:
    result = 4800
  elif speed == B9600:
    result = 9600
  elif speed == B19200:
    result = 19200
  elif speed == B38400:
    result = 38400
  else:
    raise newException(InvalidBaudRateError, "Unknown baud rate with value: " & $speed)

proc setParity(settings: var Termios, parity: Parity) =
  case parity
  of Parity.None, Parity.Mark, Parity.Space:
    # Mark and Space aren't officially supported in POSIX, but can be emulated with some tricks - we leave these tricks up to the consumer though
    settings.c_cflag = settings.c_cflag and (not PARENB)

    settings.c_iflag = settings.c_iflag and (not (INPCK or ISTRIP))
  of Parity.Odd:
    settings.c_cflag = settings.c_cflag or PARENB
    settings.c_cflag = settings.c_cflag or PARODD

    settings.c_iflag = settings.c_iflag or (INPCK or ISTRIP)
  of Parity.Even:
    settings.c_cflag = settings.c_cflag or PARENB
    settings.c_cflag = settings.c_cflag and (not PARODD)

    settings.c_iflag = settings.c_iflag or (INPCK or ISTRIP)

proc `parity=`*(port: SerialPort, parity: Parity) =
  ## Set the parity for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot set the parity whilst the serial port is closed")

  var settings: Termios
  if tcGetAttr(port.handle, addr settings) == -1:
    raiseOSError(osLastError())

  setParity(settings, parity)

  if tcSetAttr(port.handle, TCSANOW, addr settings) == -1:
    raiseOSError(osLastError())

proc parity*(port: SerialPort): Parity =
  ## Get the parity for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the parity whilst the serial port is closed")

  var settings: Termios
  if tcGetAttr(port.handle, addr settings) == -1:
    raiseOSError(osLastError())

  if (settings.c_cflag and PARENB) == 0:
    result = Parity.None
  elif (settings.c_cflag and PARODD) == PARODD:
    result = Parity.Odd
  else:
    result = Parity.Even

proc `breakStatus=`*(port: SerialPort, shouldBreak: bool) =
  ## Set the break state on the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot break whilst the serial port is closed")

  if shouldBreak:
    if tcsendbreak(port.handle, 0) == -1:
      raiseOSError(osLastError())

proc breakStatus*(port: SerialPort): bool =
  ## Get whether the serial port is currently in a break state.
  ##
  ## This isn't currently implemented in the posix version.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get break whilst the serial port is closed")

  result = false

proc `dtrEnable=`*(port: SerialPort, dtrEnabled: bool) =
  ## Set or clear the data terminal ready signal.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot change the data terminal ready signal status whilst the serial port is closed")

  var flag = TIOCM_DTR
  if dtrEnabled:
    if ioctl(port.handle, TIOCMBIS, addr flag) == -1:
      raiseOSError(osLastError())
  else:
    if ioctl(port.handle, TIOCMBIC, addr flag) == -1:
      raiseOSError(osLastError())

proc dtrEnable*(port: SerialPort): bool =
  ## Check whether the data terminal ready signal is currently set.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the data terminal ready signal status whilst the serial port is closed")

  var flag: cint
  if ioctl(port.handle, TIOCMGET, addr flag) == -1:
    raiseOSError(osLastError())

  result = (flag and TIOCM_DTR) == TIOCM_DTR

proc `rtsEnable=`*(port: SerialPort, rtsEnabled: bool) =
  ## Set or clear the ready to send signal.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot change the ready to send signal status whilst the serial port is closed")

  if port.handshake in {Handshake.RequestToSend, Handshake.RequestToSendXOnXOff}:
    raise newException(InvalidSerialPortStateError, "Cannot set or clear RTS when using RTS or RTS XON/XOFF handshaking")

  var flag = TIOCM_RTS
  if rtsEnabled:
    if ioctl(port.handle, TIOCMBIS, addr flag) == -1:
      raiseOSError(osLastError())
  else:
    if ioctl(port.handle, TIOCMBIC, addr flag) == -1:
      raiseOSError(osLastError())

proc rtsEnable*(port: SerialPort): bool =
  ## Check whether the ready to send signal is currently set.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the ready to send signal status whilst the serial port is closed")

  var flag: cint
  if ioctl(port.handle, TIOCMGET, addr flag) == -1:
    raiseOSError(osLastError())

  result = (flag and TIOCM_RTS) == TIOCM_RTS

proc setHandshaking(settings: var Termios, handshake: Handshake) =
  case handshake
  of Handshake.None:
    settings.c_cflag = settings.c_cflag and (not CRTSCTS)
    settings.c_iflag = settings.c_iflag and (not (IXON or IXOFF or IXANY))
  of Handshake.XOnXOff:
    settings.c_iflag = settings.c_iflag or (IXON or IXOFF or IXANY)
  of Handshake.RequestToSend:
    settings.c_cflag = settings.c_cflag or CRTSCTS
  of Handshake.RequestToSendXOnXOff:
    settings.c_cflag = settings.c_cflag or CRTSCTS
    settings.c_iflag = settings.c_iflag or (IXON or IXOFF or IXANY)

proc `handshake=`*(port: SerialPort, handshake: Handshake) =
  ## Set the handshaking type for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot set the handshaking method whilst the serial port is closed")

  var settings: Termios
  if tcGetAttr(port.handle, addr settings) == -1:
    raiseOSError(osLastError())

  setHandshaking(settings, handshake)

  if tcSetAttr(port.handle, TCSANOW, addr settings) == -1:
    raiseOSError(osLastError())

proc handshake*(port: SerialPort): Handshake =
  ## Get the handshaking type for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the handshaking method whilst the serial port is closed")

  result = port.handshake

proc open*(port: SerialPort, baudRate: int32, parity: Parity, dataBits: byte, stopBits: StopBits,
           handshaking: Handshake = Handshake.None, readTimeout = TIMEOUT_INFINITE,
           writeTimeout = TIMEOUT_INFINITE, dtrEnable = false, rtsEnable = false) =
  ## Open the serial port for reading and writing.
  ##
  ## The `readTimeout` and `writeTimeout` are in milliseconds.
  if port.isOpen():
    raise newException(InvalidSerialPortStateError, "Serial port is already open.")

  let tempHandle = posix.open(port.name, O_RDWR or O_NOCTTY)
  if tempHandle == -1:
    raiseOSError(osLastError())

  try:
    # Check the opened port is a serial port
    if isatty(tempHandle) != 1:
      raiseOSError(osLastError())

    var settings: Termios
    if tcGetAttr(tempHandle, addr settings) == -1:
      raiseOSError(osLastError())

    setSpeed(addr settings, baudRate)

    settings.c_cflag = settings.c_cflag or (CLOCAL or CREAD)
    settings.c_lflag = settings.c_lflag and (not (ICANON or ECHO or ECHOE or ISIG))
    settings.c_oflag = settings.c_oflag and (not OPOST)

    setParity(settings, parity)
    setDataBits(settings, dataBits)
    setStopBits(settings, stopBits)
    setHandshaking(settings, handshaking)

    port.readTimeout = readTimeout
    port.writeTimeout = writeTimeout

    if tcSetAttr(tempHandle, TCSANOW, addr settings) == -1:
      raiseOSError(osLastError())

    port.handle = FileHandle(tempHandle)
  finally:
    discard posix.close(tempHandle)
    port.handle = InvalidFileHandle

proc read*(port: SerialPort, buff: pointer, len: int32): int32 =
  ## Read up to `len` bytes from the serial port into the buffer `buff`. This will return the actual number of bytes that were received.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Port must be open in order to read from it")

  if port.readTimeout > 0'i32:
    var
      selectSet: TFdSet
      timer: Timeval

    FD_ZERO(selectSet)
    FD_SET(port.handle, selectSet)

    timer.tv_usec = clong(port.readTimeout * 1000)

    let selected = select(cint(port.handle + 1), addr selectSet, nil, nil, addr timer)

    case selected
    of -1:
      raiseOSError(osLastError())
    of 0:
      raise newException(TimeoutError, "Read timed out after " & $port.readTimeout & " seconds")
    else:
      let numRead = posix.read(port.handle, buff, int(len))

      if numRead == -1:
        raiseOSError(osLastError())

      result = int32(numRead)
  else:
    let numRead = posix.read(port.handle, buff, int(len))
    if numRead == -1:
      raiseOSError(osLastError())

    result = int32(numRead)

proc write*(port: SerialPort, buff: pointer, len: int32): int32 =
  ## Write up to `len` bytes to the serial port from the buffer `buff`. This will return the number of bytes that were written.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Port must be open in order to write to it")

  if port.writeTimeout > 0'i32:
    var
      selectSet: TFdSet
      timer: Timeval

    FD_ZERO(selectSet)
    FD_SET(port.handle, selectSet)

    timer.tv_usec = clong(port.writeTimeout * 1000)

    let selected = select(cint(port.handle + 1), nil, addr selectSet, nil, addr timer)

    case selected
    of -1:
      raiseOSError(osLastError())
    of 0:
      raise newException(TimeoutError, "Write timed out after " & $port.writeTimeout & " seconds")
    else:
      let numWritten = posix.write(port.handle, buff, int(len))

      if numWritten == -1:
        raiseOSError(osLastError())

      result = int32(numWritten)
  else:
    let numWritten = posix.write(port.handle, buff, int(len))
    if numWritten == -1:
      raiseOSError(osLastError())

    result = int32(numWritten)

proc flush*(port: SerialPort) =
  ## Flush the buffers for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Port must be open in order to be flushed")

  if tcflush(port.handle, TCIOFLUSH) == -1:
    raiseOSError(osLastError())

proc close*(port: SerialPort) =
  ## Close the serial port.
  if port.isOpen():
    try:
      port.flush()
    finally:
      discard posix.close(port.handle)
      port.handle = InvalidFileHandle
