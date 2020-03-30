## Serial port handling for POSIX.

import ./serialport_common

export serialport_common

import os, posix, posix/termios, asyncdispatch

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
  SerialPortBase[HandleType] = ref object of RootObj
    name*: string
    handshake: Handshake
    handle: HandleType
    readTimeout: int32
    writeTimeout: int32

  SerialPort* = ref object of SerialPortBase[FileHandle]
    ## A serial port type used to read from and write to serial ports.

  AsyncSerialPort* = ref object of SerialPortBase[AsyncFD]
    ## A serial port type used to read from and write to serial ports asynchronously.

proc ioctl(handle: cint, command: cint, arg: ptr cint): cint {.importc,
    header: "<sys/ioctl.h>".}

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

proc newAsyncSerialPort*(portName: string): AsyncSerialPort =
  ## Initialise a new serial port, ready to open.
  if not existsPort(portName):
    raise newException(InvalidSerialPortError, "Serialport path '" & portName & "' does not exist or is not a character device")

  result = AsyncSerialPort(
      name: portName,
      handle: AsyncFD(InvalidFileHandle)
  )

proc isOpen*(port: SerialPort | AsyncSerialPort): bool =
  ## Check whether the serial port is currently open.
  result = FileHandle(port.handle) != InvalidFileHandle

proc getTimeouts*(port: SerialPort | AsyncSerialPort): tuple[readTimeout: int32,
    writeTimeout: int32] =
  ## Get the read and write timeouts for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get timeouts whilst the serial port is closed")

  result = (readTimeout: port.readTimeout, writeTimeout: port.writeTimeout)

proc setTimeouts*(port: SerialPort | AsyncSerialPort, readTimeout: int32,
    writeTimeout: int32) =
  ## Set the read and write timeouts for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot set timeouts whilst the serial port is closed")

  port.readTimeout = readTimeout
  port.writeTimeout = writeTimeout

proc isCarrierHolding*(port: SerialPort | AsyncSerialPort): bool =
  ## Check whether the carrier signal is currently active.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot check the carrier signal whilst the serial port is closed")

  var flag: cint
  if ioctl(cint(port.handle), TIOCMGET, addr flag) == -1:
    raiseOSError(osLastError())

  result = (flag and TIOCM_CAR) == TIOCM_CAR

proc isCtsHolding*(port: SerialPort | AsyncSerialPort): bool =
  ## Check whether the clear to send signal is currently active.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot check the clear to send signal whilst the serial port is closed")

  var flag: cint
  if ioctl(cint(port.handle), TIOCMGET, addr flag) == -1:
    raiseOSError(osLastError())

  result = (flag and TIOCM_CTS) == TIOCM_CTS

proc isDsrHolding*(port: SerialPort | AsyncSerialPort): bool =
  ## Check whether the data set ready signal is currently active.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot check the data set ready signal whilst the serial port is closed")

  var flag: cint
  if ioctl(cint(port.handle), TIOCMGET, addr flag) == -1:
    raiseOSError(osLastError())

  result = (flag and TIOCM_LE) == TIOCM_LE

proc isRingHolding*(port: SerialPort | AsyncSerialPort): bool =
  ## Check whether the ring signal is currently active.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot check the ring signal whilst the serial port is closed")

  var flag: cint
  if ioctl(cint(port.handle), TIOCMGET, addr flag) == -1:
    raiseOSError(osLastError())

  result = (flag and TIOCM_RNG) == TIOCM_RNG

proc setStopBits(settings: var Termios, stopBits: StopBits) =
  case stopBits
  of StopBits.One:
    settings.c_cflag = settings.c_cflag and (not CSTOPB)
  of StopBits.Two, StopBits.OnePointFive:
    settings.c_cflag = settings.c_cflag or CSTOPB

proc `stopBits=`*(port: SerialPort | AsyncSerialPort, stopBits: StopBits) =
  ## Set the stop bits for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot set the stop bits whilst the serial port is closed")

  var settings: Termios
  if tcGetAttr(cint(port.handle), addr settings) == -1:
    raiseOSError(osLastError())

  setStopBits(settings, stopBits)

  if tcSetAttr(cint(port.handle), TCSANOW, addr settings) == -1:
    raiseOSError(osLastError())

proc stopBits*(port: SerialPort | AsyncSerialPort): StopBits =
  ## Get the current stop bits for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the stop bits whilst the serial port is closed")

  var settings: Termios
  if tcGetAttr(cint(port.handle), addr settings) == -1:
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
    raise newException(InvalidDataBitsError, "Invalid number of data bits: '" &
        $dataBits & "'")

proc `dataBits=`*(port: SerialPort | AsyncSerialPort, dataBits: byte) =
  ## Set the number of data bits for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot set the data bits whilst the serial port is closed")

  var settings: Termios
  if tcGetAttr(cint(port.handle), addr settings) == -1:
    raiseOSError(osLastError())

  setDataBits(settings, dataBits)

  if tcSetAttr(cint(port.handle), TCSANOW, addr settings) == -1:
    raiseOSError(osLastError())

proc dataBits*(port: SerialPort | AsyncSerialPort): byte =
  ## Get the number of data bits for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the data bits whilst the serial port is closed")

  var settings: Termios
  if tcGetAttr(cint(port.handle), addr settings) == -1:
    raiseOSError(osLastError())

  if (settings.c_cflag and CS8) == CS8:
    result = 8
  elif (settings.c_cflag and CS7) == CS7:
    result = 7
  elif (settings.c_cflag and CS6) == CS6:
    result = 6
  else:
    result = 5

# these constants should be in termios.h
# but some higher values are not present on
# certain implementations.
when defined(macosx):
  const B460800 = 460800
  const B500000 = 500000
  const B576000 = 576000
  const B921600 = 921600
  const B1000000 = 1000000
  const B1152000 = 1152000
  const B1500000 = 1500000
  const B2000000 = 2000000
  const B2500000 = 2500000
  const B3000000 = 3000000
  const B3500000 = 3500000
  const B4000000 = 4000000

# and the missing constants for linux
when not declared(B57600):
  const B57600 = 0o010001
when not declared(B115200):
  const B115200 = 0o010002
when not declared(B230400):
  const B230400 = 0o010003
when not declared(B460800):
  const B460800 = 0o010004
when not declared(B500000):
  const B500000 = 0o010005
when not declared(B576000):
  const B576000 = 0o010006
when not declared(B921600):
  const B921600 = 0o010007
when not declared(B1000000):
  const B1000000 = 0o010010
when not declared(B1152000):
  const B1152000 = 0o010011
when not declared(B1500000):
  const B1500000 = 0o010012
when not declared(B2000000):
  const B2000000 = 0o010013
when not declared(B2500000):
  const B2500000 = 0o010014
when not declared(B3000000):
  const B3000000 = 0o010015
when not declared(B3500000):
  const B3500000 = 0o010016
when not declared(B4000000):
  const B4000000 = 0o010017


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
  of 57600:
    baud = B57600
  of 115200:
    baud = B115200
  of 230400:
    baud = B230400
  of 460800:
    baud = B460800
  of 500000:
    baud = B500000
  of 576000:
    baud = B576000
  of 921600:
    baud = B921600
  of 1000000:
    baud = B1000000
  of 1152000:
    baud = B1152000
  of 1500000:
    baud = B1500000
  of 2000000:
    baud = B2000000
  of 2500000:
    baud = B2500000
  of 3000000:
    baud = B3000000
  of 3500000:
    baud = B3500000
  of 4000000:
    baud = B4000000
  else:
    raise newException(InvalidBaudRateError, "Unsupported baud rate '" &
        $speed & "'")

  if cfSetIspeed(settings, baud) == -1:
    raiseOSError(osLastError())

  if cfSetOspeed(settings, baud) == -1:
    raiseOSError(osLastError())

proc `baudRate=`*(port: SerialPort | AsyncSerialPort, baudRate: int32) =
  ## Set the baud rate for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot set the baud rate whilst the serial port is closed")

  var settings: Termios
  if tcGetAttr(cint(port.handle), addr settings) == -1:
    raiseOSError(osLastError())

  setSpeed(addr settings, baudRate)

  if tcSetAttr(cint(port.handle), TCSANOW, addr settings) == -1:
    raiseOSError(osLastError())

proc baudRate*(port: SerialPort | AsyncSerialPort): int32 =
  ## Get the current baud rate for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the baud rate whilst the serial port is closed")

  var settings: Termios
  if tcGetAttr(cint(port.handle), addr settings) == -1:
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
  elif speed == B57600:
    result = 57600
  elif speed == B115200:
    result = 115200
  elif speed == B230400:
    result = 230400
  elif speed == B460800:
    result = 460800
  elif speed == B500000:
    result = 500000
  elif speed == B576000:
    result = 576000
  elif speed == B921600:
    result = 921600
  elif speed == B1000000:
    result = 1000000
  elif speed == B1152000:
    result = 1152000
  elif speed == B1500000:
    result = 1500000
  elif speed == B2000000:
    result = 2000000
  elif speed == B2500000:
    result = 2500000
  elif speed == B3000000:
    result = 3000000
  elif speed == B3500000:
    result = 3500000
  elif speed == B4000000:
    result = 4000000
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

proc `parity=`*(port: SerialPort | AsyncSerialPort, parity: Parity) =
  ## Set the parity for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot set the parity whilst the serial port is closed")

  var settings: Termios
  if tcGetAttr(cint(port.handle), addr settings) == -1:
    raiseOSError(osLastError())

  setParity(settings, parity)

  if tcSetAttr(cint(port.handle), TCSANOW, addr settings) == -1:
    raiseOSError(osLastError())

proc parity*(port: SerialPort | AsyncSerialPort): Parity =
  ## Get the parity for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the parity whilst the serial port is closed")

  var settings: Termios
  if tcGetAttr(cint(port.handle), addr settings) == -1:
    raiseOSError(osLastError())

  if (settings.c_cflag and PARENB) == 0:
    result = Parity.None
  elif (settings.c_cflag and PARODD) == PARODD:
    result = Parity.Odd
  else:
    result = Parity.Even

proc `breakStatus=`*(port: SerialPort | AsyncSerialPort, shouldBreak: bool) =
  ## Set the break state on the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot break whilst the serial port is closed")

  if shouldBreak:
    if tcsendbreak(cint(port.handle), 0) == -1:
      raiseOSError(osLastError())

proc breakStatus*(port: SerialPort | AsyncSerialPort): bool =
  ## Get whether the serial port is currently in a break state.
  ##
  ## This isn't currently implemented in the posix version.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get break whilst the serial port is closed")

  result = false

proc `dtrEnable=`*(port: SerialPort | AsyncSerialPort, dtrEnabled: bool) =
  ## Set or clear the data terminal ready signal.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot change the data terminal ready signal status whilst the serial port is closed")

  var flag = TIOCM_DTR
  if dtrEnabled:
    if ioctl(cint(port.handle), TIOCMBIS, addr flag) == -1:
      raiseOSError(osLastError())
  else:
    if ioctl(cint(port.handle), TIOCMBIC, addr flag) == -1:
      raiseOSError(osLastError())

proc dtrEnable*(port: SerialPort | AsyncSerialPort): bool =
  ## Check whether the data terminal ready signal is currently set.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the data terminal ready signal status whilst the serial port is closed")

  var flag: cint
  if ioctl(cint(port.handle), TIOCMGET, addr flag) == -1:
    raiseOSError(osLastError())

  result = (flag and TIOCM_DTR) == TIOCM_DTR

proc `rtsEnable=`*(port: SerialPort | AsyncSerialPort, rtsEnabled: bool) =
  ## Set or clear the ready to send signal.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot change the ready to send signal status whilst the serial port is closed")

  if port.handshake in {Handshake.RequestToSend,
      Handshake.RequestToSendXOnXOff}:
    raise newException(InvalidSerialPortStateError, "Cannot set or clear RTS when using RTS or RTS XON/XOFF handshaking")

  var flag = TIOCM_RTS
  if rtsEnabled:
    if ioctl(cint(port.handle), TIOCMBIS, addr flag) == -1:
      raiseOSError(osLastError())
  else:
    if ioctl(cint(port.handle), TIOCMBIC, addr flag) == -1:
      raiseOSError(osLastError())

proc rtsEnable*(port: SerialPort | AsyncSerialPort): bool =
  ## Check whether the ready to send signal is currently set.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the ready to send signal status whilst the serial port is closed")

  var flag: cint
  if ioctl(cint(port.handle), TIOCMGET, addr flag) == -1:
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

proc `handshake=`*(port: SerialPort | AsyncSerialPort, handshake: Handshake) =
  ## Set the handshaking type for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot set the handshaking method whilst the serial port is closed")

  var settings: Termios
  if tcGetAttr(cint(port.handle), addr settings) == -1:
    raiseOSError(osLastError())

  setHandshaking(settings, handshake)

  if tcSetAttr(cint(port.handle), TCSANOW, addr settings) == -1:
    raiseOSError(osLastError())

proc handshake*(port: SerialPort): Handshake =
  ## Get the handshaking type for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the handshaking method whilst the serial port is closed")

  result = port.handshake

proc initPort(port: SerialPort | AsyncSerialPort, tempHandle: cint, baudRate: int32, parity: Parity, dataBits: byte, stopBits: StopBits,
              handshaking: Handshake = Handshake.None,
                  readTimeout = TIMEOUT_INFINITE,
              writeTimeout = TIMEOUT_INFINITE, dtrEnable = false,
                  rtsEnable = false) {.inline.} =
  when port is AsyncSerialPort:
    var registered = false

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
    settings.c_iflag = settings.c_iflag and (not (INLCR or IGNCR or ICRNL))

    setParity(settings, parity)
    setDataBits(settings, dataBits)
    setStopBits(settings, stopBits)
    setHandshaking(settings, handshaking)

    port.readTimeout = readTimeout
    port.writeTimeout = writeTimeout

    if tcSetAttr(tempHandle, TCSANOW, addr settings) == -1:
      raiseOSError(osLastError())

    when port is AsyncSerialPort:
      port.handle = AsyncFD(tempHandle)
      register(port.handle)
      registered = true
    else:
      port.handle = FileHandle(tempHandle)
  except:
    when port is AsyncSerialPort:
      if registered:
        unregister(port.handle)

    discard posix.close(tempHandle)
    port.handle = when port is AsyncSerialPort: AsyncFD(
        InvalidFileHandle) else: InvalidFileHandle

    raise

proc open*(port: SerialPort, baudRate: int32, parity: Parity, dataBits: byte, stopBits: StopBits,
           handshaking: Handshake = Handshake.None,
               readTimeout = TIMEOUT_INFINITE,
           writeTimeout = TIMEOUT_INFINITE, dtrEnable = false,
               rtsEnable = false) =
  ## Open the serial port for reading and writing.
  ##
  ## The `readTimeout` and `writeTimeout` are in milliseconds.
  if port.isOpen():
    raise newException(InvalidSerialPortStateError, "Serial port is already open.")

  let tempHandle = posix.open(port.name, O_RDWR or O_NOCTTY or O_NONBLOCK)
  if tempHandle == -1:
    raiseOSError(osLastError())

  initPort(port, tempHandle, baudRate, parity, dataBits, stopBits, handshaking,
      readTimeout, writeTimeout, dtrEnable, rtsEnable)

proc open*(port: AsyncSerialPort, baudRate: int32, parity: Parity, dataBits: byte, stopBits: StopBits,
           handshaking: Handshake = Handshake.None,
               readTimeout = TIMEOUT_INFINITE,
           writeTimeout = TIMEOUT_INFINITE, dtrEnable = false,
               rtsEnable = false) =
  ## Open the serial port for reading and writing.
  ##
  ## The `readTimeout` and `writeTimeout` are in milliseconds.
  if port.isOpen():
    raise newException(InvalidSerialPortStateError, "Serial port is already open.")

  let tempHandle = posix.open(port.name, O_RDWR or O_NOCTTY)
  if tempHandle == -1:
    raiseOSError(osLastError())

  initPort(port, tempHandle, baudRate, parity, dataBits, stopBits, handshaking,
      readTimeout, writeTimeout, dtrEnable, rtsEnable)

proc getPosixMs(): int64 = 
  var currentTime: Timespec
  if (clock_gettime(CLOCK_MONOTONIC, currentTime) != 0):
    raiseOSError(osLastError())
  result = int64(currentTime.tv_sec) * 1000
  result += int64(currentTime.tv_nsec) div 1000000'i64

proc read*(port: SerialPort, buff: pointer, len: int32): int32 =
  ## Read up to `len` bytes from the serial port into the buffer `buff`. This will return the actual number of bytes that were received.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Port must be open in order to read from it")

  if port.readTimeout != 0'i32:
    var
      selectSet: TFdSet
      timer: Timeval
      ptrTimer: ptr Timeval
      endTime: int64
      timeLeft: int64

    timeLeft = port.readTimeout
    endTime = getPosixMs() + timeLeft

    var totalNumRead = 0;
    
    while(totalNumRead < len and timeLeft > 0):

      FD_ZERO(selectSet)
      FD_SET(port.handle, selectSet)

      timer.tv_usec = Suseconds((timeLeft mod 1000) * 1000)
      timer.tv_sec = Time(timeLeft div 1000)

      if port.readTimeout < 0:
        ptrTimer = nil
      else:
        ptrTimer = addr timer

      let selected = select(cint(port.handle + 1), addr selectSet, nil, nil, ptrTimer)

      case selected
      of -1:
        raiseOSError(osLastError())
      of 0:
        if (totalNumRead == 0):
          raise newException(TimeoutError, "Read timed out after " &
              $port.readTimeout & " milliseconds")
        else:
          break
      else:
        var numRead = posix.read(port.handle, cast[pointer](cast[int](buff)+totalNumRead), int(len-totalNumRead))

        if numRead == -1:
          raiseOSError(osLastError())

        totalNumRead += numRead

      timeLeft = endTime - getPosixMs()
          
    result = int32(totalNumRead)

  else:
    let numRead = posix.read(port.handle, buff, int(len))
    if numRead == -1:
      # port FD is set to O_NONBLOCK so EWOULDBLOCK error is set when 
      # no data is available, which is treated as a timeout condition.
      # This means that posix behaves the same as windows. 
      if cint(osLastError()) == EWOULDBLOCK:
        raise newException(TimeoutError, "Read timed out after 0 milliseconds")
      else:
        raiseOSError(osLastError())

    result = int32(numRead)

proc read*(port: AsyncSerialPort, buff: pointer, len: int32): Future[int32] =
  ## Read up to `len` bytes from the serial port into the buffer `buff`. This will return the actual number of bytes that were received.
  var retFuture = newFuture[int32]("serialport.read")

  if not port.isOpen():
    retFuture.fail(newException(InvalidSerialPortStateError,
        "Port must be open in order to write to it"))
    return retFuture

  proc cb(fd: AsyncFD): bool =
    result = true
    let res = posix.read(cint(fd), cast[cstring](buff), cint(len))
    if res < 0:
      let lastError = osLastError()
      if int32(lastError) != EAGAIN:
        retFuture.fail(newException(OSError, osErrorMsg(lastError)))
      else:
        result = false # We still want this callback to be called.
    else:
      retFuture.complete(int32(res))

  addRead(port.handle, cb)

  return retFuture

proc write*(port: SerialPort, buff: pointer, len: int32): int32 =
  ## Write up to `len` bytes to the serial port from the buffer `buff`. This will return the number of bytes that were written.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Port must be open in order to write to it")

  if port.writeTimeout != 0'i32:
    var
      selectSet: TFdSet
      timer: Timeval
      ptrTimer: ptr Timeval

    FD_ZERO(selectSet)
    FD_SET(port.handle, selectSet)

    timer.tv_usec = Suseconds(port.writeTimeout * 1000)

    if port.writeTimeout < 0:
      ptrTimer = nil
    else:
      ptrTimer = addr timer

    let selected = select(cint(port.handle + 1), nil, addr selectSet, nil, ptrTimer)

    case selected
    of -1:
      raiseOSError(osLastError())
    of 0:
      raise newException(TimeoutError, "Write timed out after " &
          $port.writeTimeout & " seconds")
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

proc write*(port: AsyncSerialPort, buff: pointer, len: int32): Future[int32] =
  ## Write up to `len` bytes to the serial port from the buffer `buff`. This will return the number of bytes that were written.
  ##
  ## Note that this doesn't currently respect timeout settings on posix.
  var retFuture = newFuture[int32]("serialport.write")

  if not port.isOpen():
    retFuture.fail(newException(InvalidSerialPortStateError,
        "Port must be open in order to write to it"))
    return retFuture

  proc cb(fd: AsyncFD): bool =
    result = true
    var cbuf = cast[cstring](buff)
    let res = posix.write(cint(fd), addr cbuf[0], cint(len))
    if res < 0:
      let lastError = osLastError()
      if int32(lastError) != EAGAIN:
        retFuture.fail(newException(OSError, osErrorMsg(lastError)))
      else:
        result = false # We still want this callback to be called.
    else:
      retFuture.complete(int32(res))

  addWrite(port.handle, cb)

  return retFuture

proc flush*(port: SerialPort | AsyncSerialPort) =
  ## Flush the buffers for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Port must be open in order to be flushed")

  if tcflush(cint(port.handle), TCIOFLUSH) == -1:
    raiseOSError(osLastError())

proc close*(port: SerialPort | AsyncSerialPort) =
  ## Close the serial port.
  if port.isOpen():
    try:
      port.flush()
    finally:
      when port is AsyncSerialPort:
        unregister(port.handle)

      discard posix.close(cint(port.handle))
      port.handle = when port is AsyncSerialPort: AsyncFD(
          InvalidFileHandle) else: InvalidFileHandle

