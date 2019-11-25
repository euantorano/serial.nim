## Serial port handling for Windows.

import ./serialport_common, ../ffi/ffi_windows

export serialport_common

import winlean, os, asyncdispatch

const
  FileAccess: DWORD = DWORD(GENERIC_READ or GENERIC_WRITE)
  FileShareMode: DWORD = DWORD(0)
  FileCreationDisposition: DWORD = DWORD(OPEN_EXISTING)
  FileFlagsAndAttributes: DWORD = DWORD(FILE_ATTRIBUTE_NORMAL)
  AsyncFileFlagsAndAttributes: DWORD = DWORD(FILE_FLAG_OVERLAPPED)
  FileTemplateHandle: Handle = Handle(0)

type
  SerialPortBase[HandleType] = ref object of RootObj
    name*: string
    handshake: Handshake
    handle: HandleType
    commProp: CommProp
    comStat: ComStat
    dcb: DCB
    commTimeouts: COMMTIMEOUTS
    isRtsEnabled: bool
    isInBreak: bool

  SerialPort* = ref object of SerialPortBase[FileHandle]
    ## A serial port type used to read from and write to serial ports.

  AsyncSerialPort* = ref object of SerialPortBase[AsyncFD]
    ## A serial port type used to read from and write to serial ports asynchronously.

proc newSerialPort*(portName: string): SerialPort =
  ## Initialise a new serial port, ready to open.
  if len(portName) < 4 or portName[0..2] != "COM":
    raise newException(InvalidSerialPortError, "Serial port name must start with 'COM' on Windows.")

  result = SerialPort(
    name: portName,
    handle: InvalidFileHandle
  )

proc newAsyncSerialPort*(portName: string): AsyncSerialPort =
  ## Initialise a new serial port, ready to open.
  if len(portName) < 4 or portName[0..2] != "COM":
    raise newException(InvalidSerialPortError, "Serial port name must start with 'COM' on Windows.")

  result = AsyncSerialPort(
    name: portName,
    handle: AsyncFD(InvalidFileHandle)
  )

proc isOpen*(port: SerialPort | AsyncSerialPort): bool =
  ## Check whether the serial port is currently open.
  result = FileHandle(port.handle) != InvalidFileHandle

proc initDcb(port: SerialPort | AsyncSerialPort, baudRate: int32, parity: Parity, dataBits: byte, stopBits: StopBits, handshaking: Handshake) =
  if GetCommState(Handle(port.handle), addr port.dcb) == 0:
    raiseOSError(osLastError())

  port.dcb.DCBlength = DWORD(sizeof(port.dcb))

  port.dcb.BaudRate = DWORD(baudRate)
  port.dcb.ByteSize = dataBits

  case stopBits
  of StopBits.One:
    port.dcb.StopBits = ONESTOPBIT
  of StopBits.Two:
    port.dcb.StopBits = TWOSTOPBITS
  of StopBits.OnePointFive:
    port.dcb.StopBits = ONE5STOPBITS
  #mp035: remove invalid else case
  #else:
  #  raise newException(InvalidStopBitsError, "Invalid number of stop bits '" & $stopBits & "'")

  port.dcb.Parity = byte(parity)

  port.dcb.fParity = if parity == Parity.None: 0 else: 1

  # Always set binary mode to true
  port.dcb.fBinary = 1

  case handshaking
  of Handshake.RequestToSend, Handshake.RequestToSendXOnXOff:
    port.dcb.fOutxCtsFlow = DWORD(1)
    port.dcb.fInX = DWORD(1)
    port.dcb.fOutX = DWORD(1)
  else:
    port.dcb.fOutxCtsFlow = DWORD(0)
    port.dcb.fInX = DWORD(0)
    port.dcb.fOutX = DWORD(0)

  # dsrTimeout is always set to 0.
  port.dcb.fOutxDsrFlow = 0
  port.dcb.fDtrControl = DTR_CONTROL_DISABLE
  port.dcb.fDsrSensitivity = 0

  if parity != Parity.None:
    port.dcb.fErrorChar = 1
    port.dcb.ErrorChar = '?'
  else:
    port.dcb.fErrorChar = 0
    port.dcb.ErrorChar = '\0'

  port.dcb.fNull = 0

  case handshaking
  of Handshake.RequestToSend, Handshake.RequestToSendXOnXOff:
    port.dcb.fRtsControl = RTS_CONTROL_HANDSHAKE
  else:
    if port.dcb.fRtsControl == RTS_CONTROL_HANDSHAKE:
      port.dcb.fRtsControl = RTS_CONTROL_DISABLE

  port.dcb.XonLim = WORD(port.commProp.dwCurrentRxQueue / 4)
  port.dcb.XoffLim = WORD(port.commProp.dwCurrentRxQueue / 4)

  port.dcb.XonChar = cchar(17)
  port.dcb.XoffChar = cchar(19)
  port.dcb.EofChar = cchar(26)
  port.dcb.EvtChar = cchar(26)

  if SetCommState(Handle(port.handle), addr port.dcb) == 0:
    raiseOSError(osLastError())

proc getTimeouts*(port: SerialPort | AsyncSerialPort): tuple[readTimeout: int32, writeTimeout: int32] =
  ## Get the read and write timeouts for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get timeouts whilst the serial port is closed")

  result = (
    readTimeout: if port.commTimeouts.ReadTotalTimeoutConstant == -2: TIMEOUT_INFINITE else: port.commTimeouts.ReadTotalTimeoutConstant,
    writeTimeout: if port.commTimeouts.WriteTotalTimeoutConstant == 0: TIMEOUT_INFINITE else: port.commTimeouts.WriteTotalTimeoutConstant
  )

proc setTimeouts*(port: SerialPort | AsyncSerialPort, readTimeout: int32, writeTimeout: int32) =
  ## Set the read and write timeouts for the serial port. Timeouts are in milliseconds.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot set timeouts whilst the serial port is closed")

  let oldReadTotalTimeoutConstant = port.commTimeouts.ReadTotalTimeoutConstant
  let oldReadTotalTimeoutMultiplier = port.commTimeouts.ReadTotalTimeoutMultiplier
  let oldReadIntervalTimeout = port.commTimeouts.ReadIntervalTimeout
  let oldWriteTotalTimeoutMultiplier = port.commTimeouts.WriteTotalTimeoutMultiplier
  let oldWriteTotalTimeoutConstant = port.commTimeouts.WriteTotalTimeoutConstant

  case readTimeout
  of 0:
    port.commTimeouts.ReadTotalTimeoutConstant = 0
    port.commTimeouts.ReadTotalTimeoutMultiplier = 0
    port.commTimeouts.ReadIntervalTimeout = MAXDWORD
  of TIMEOUT_INFINITE:
    port.commTimeouts.ReadTotalTimeoutConstant = -2
    port.commTimeouts.ReadTotalTimeoutMultiplier = MAXDWORD
    port.commTimeouts.ReadIntervalTimeout = MAXDWORD
  else:
    port.commTimeouts.ReadTotalTimeoutConstant = readTimeout
    port.commTimeouts.ReadTotalTimeoutMultiplier = MAXDWORD
    port.commTimeouts.ReadIntervalTimeout = MAXDWORD

  port.commTimeouts.WriteTotalTimeoutMultiplier = 0
  port.commTimeouts.WriteTotalTimeoutConstant = if writeTimeout == -1: 0 else: writeTimeout

  if SetCommTimeouts(Handle(port.handle), addr port.commTimeouts) == 0:
    port.commTimeouts.ReadTotalTimeoutConstant = oldReadTotalTimeoutConstant
    port.commTimeouts.ReadTotalTimeoutMultiplier = oldReadTotalTimeoutMultiplier
    port.commTimeouts.ReadIntervalTimeout = oldReadIntervalTimeout
    port.commTimeouts.WriteTotalTimeoutMultiplier = oldWriteTotalTimeoutMultiplier
    port.commTimeouts.WriteTotalTimeoutConstant = oldWriteTotalTimeoutConstant

    raiseOSError(osLastError())

proc isCarrierHolding*(port: SerialPort | AsyncSerialPort): bool =
  ## Check whether the carrier signal is currently active.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot check the carrier signal whilst the serial port is closed")

  var pinStatus: int32
  if GetCommModemStatus(Handle(port.handle), addr pinStatus) == 0:
    raiseOSError(osLastError())

  result = (pinStatus and MS_RLSD_ON) != 0

proc isCtsHolding*(port: SerialPort| AsyncSerialPort): bool =
  ## Check whether the clear to send signal is currently active.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot check the clear to send signal whilst the serial port is closed")

  var pinStatus: int32
  if GetCommModemStatus(Handle(port.handle), addr pinStatus) == 0:
    raiseOSError(osLastError())

  result = (pinStatus and MS_CTS_ON) != 0

proc isDsrHolding*(port: SerialPort | AsyncSerialPort): bool =
  ## Check whether the data set ready signal is currently active.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot check the data set ready signal whilst the serial port is closed")

  var pinStatus: int32
  if GetCommModemStatus(Handle(port.handle), addr pinStatus) == 0:
    raiseOSError(osLastError())

  result = (pinStatus and MS_DSR_ON) != 0

proc isRingHolding*(port: SerialPort | AsyncSerialPort): bool =
  ## Check whether the ring signal is currently active.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot check the ring signal whilst the serial port is closed")

  var pinStatus: int32
  if GetCommModemStatus(Handle(port.handle), addr pinStatus) == 0:
    raiseOSError(osLastError())

  result = (pinStatus and MS_RING_ON) != 0

proc `stopBits=`*(port: SerialPort | AsyncSerialPort, stopBits: StopBits) =
  ## Set the stop bits for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot set the stop bits whilst the serial port is closed")

  var stopBitsNative: byte
  case stopBits
  of StopBits.One:
    stopBitsNative = ONESTOPBIT
  of StopBits.Two:
    stopBitsNative = TWOSTOPBITS
  of StopBits.OnePointFive:
    stopBitsNative = ONE5STOPBITS
  #mp035: remove invalid else case
  #else:
  #  raise newException(InvalidStopBitsError, "Invalid number of stop bits '" & $stopBits & "'")

  if stopBitsNative != port.dcb.StopBits:
    let oldStopBits = port.dcb.StopBits
    port.dcb.StopBits = stopBitsNative

    if SetCommState(Handle(port.handle), addr port.dcb) == 0:
      port.dcb.StopBits = oldStopBits
      raiseOSError(osLastError())

proc stopBits*(port: SerialPort | AsyncSerialPort): StopBits =
  ## Get the current stop bits for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the stop bits whilst the serial port is closed")

  case port.dcb.StopBits
  of ONESTOPBIT:
    result = StopBits.One
  of TWOSTOPBITS:
    result = StopBits.Two
  of ONE5STOPBITS:
    result = StopBits.OnePointFive
  else:
    raise newException(InvalidStopBitsError, "Unknown number of stop bits: " & $port.dcb.StopBits)

proc `dataBits=`*(port: SerialPort | AsyncSerialPort, dataBits: byte) =
  ## Set the number of data bits for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot set the data bits whilst the serial port is closed")

  if dataBits != port.dcb.ByteSize:
    let oldDataBits = port.dcb.ByteSize
    port.dcb.ByteSize = dataBits

    if SetCommState(Handle(port.handle), addr port.dcb) == 0:
      port.dcb.ByteSize = oldDataBits
      raiseOSError(osLastError())

proc dataBits*(port: SerialPort | AsyncSerialPort): byte =
  ## Get the number of data bits for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the data bits whilst the serial port is closed")

  result = port.dcb.ByteSize

proc `baudRate=`*(port: SerialPort | AsyncSerialPort, baudRate: int32) =
  ## Set the baud rate for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot set the baud rate whilst the serial port is closed")

  if baudRate <= 0 or (baudRate > port.commProp.dwMaxBaud and port.commProp.dwMaxBaud > 0):
    if port.commProp.dwMaxBaud > 0:
      raise newException(InvalidBaudRateError, "Baud rate must be greater than 0")
    else:
      raise newException(InvalidBaudRateError, "Baud rate must be greater than 0 but less than " & $port.commProp.dwMaxBaud)

  if baudrate != port.dcb.BaudRate:
    let oldBaudRate = port.dcb.BaudRate
    port.dcb.BaudRate = baudRate

    if SetCommState(Handle(port.handle), addr port.dcb) == 0:
      port.dcb.BaudRate = oldBaudRate
      raiseOSError(osLastError())

proc baudRate*(port: SerialPort | AsyncSerialPort): int32 =
  ## Get the current baud rate for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the baud rate whilst the serial port is closed")

  result = port.dcb.BaudRate

proc `parity=`*(port: SerialPort | AsyncSerialPort, parity: Parity) =
  ## Set the parity for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot set the parity whilst the serial port is closed")

  let byteParity = byte(parity)
  if byteParity != port.dcb.Parity:
    let oldParity = port.dcb.Parity
    let oldFParity = port.dcb.fParity
    let oldErrorChar = port.dcb.ErrorChar
    let oldfErrorChar = port.dcb.fErrorChar

    port.dcb.Parity = byteParity

    let parityFlag = if parity == Parity.None: DWORD(0) else: DWORD(1)
    port.dcb.fParity = parityFlag

    if parityFlag == 1:
      port.dcb.fErrorChar = 1
      port.dcb.ErrorChar = '?'
    else:
      port.dcb.fErrorChar = 0
      port.dcb.ErrorChar = '\0'

    if SetCommState(Handle(port.handle), addr port.dcb) == 0:
      port.dcb.Parity = oldParity
      port.dcb.fParity = oldFParity
      port.dcb.ErrorChar = oldErrorChar
      port.dcb.fErrorChar = oldfErrorChar

      raiseOSError(osLastError())

proc parity*(port: SerialPort | AsyncSerialPort): Parity =
  ## Get the parity for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the parity whilst the serial port is closed")

  result = Parity(port.dcb.Parity)

proc `breakStatus=`*(port: SerialPort | AsyncSerialPort, shouldBreak: bool) =
  ## Set the break state on the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot break whilst the serial port is closed")

  if shouldBreak:
    if SetCommBreak(Handle(port.handle)) == 0:
      raiseOSError(osLastError())

    port.isInBreak = true
  else:
    if ClearCommBreak(Handle(port.handle)) == 0:
      raiseOSError(osLastError())

    port.isInBreak = false

proc breakStatus*(port: SerialPort | AsyncSerialPort): bool =
  ## Get whether the serial port is currently in a break state.
  ##
  ## This isn't currently implemented in the posix version.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get break whilst the serial port is closed")

  result = port.isInBreak

proc setDtrEnable(port: SerialPort | AsyncSerialPort, dtrEnabled: bool) =
  let currentDtrControl = port.dcb.fDtrControl
  port.dcb.fDtrControl = if dtrEnabled: DTR_CONTROL_ENABLE else: DTR_CONTROL_DISABLE
  if SetCommState(Handle(port.handle), addr port.dcb) == 0:
    port.dcb.fDtrControl = currentDtrControl
    raiseOSError(osLastError())

  # Now set the actual pin
  if EscapeCommFunction(Handle(port.handle), if dtrEnabled: SETDTR else: CLRDTR) == 0:
    raiseOSError(osLastError())

proc `dtrEnable=`*(port: SerialPort | AsyncSerialPort, dtrEnabled: bool) =
  ## Set or clear the data terminal ready signal.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot change the data terminal ready signal status whilst the serial port is closed")

  setDtrEnable(port, dtrEnabled)

proc dtrEnable*(port: SerialPort | AsyncSerialPort): bool =
  ## Check whether the data terminal ready signal is currently set.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the data terminal ready signal status whilst the serial port is closed")

  result = port.dcb.fDtrControl == DTR_CONTROL_ENABLE

proc setRtsEnable(port: SerialPort | AsyncSerialPort, rtsEnabled: bool) =
  if port.handshake in {Handshake.RequestToSend, Handshake.RequestToSendXOnXOff}:
    raise newException(InvalidSerialPortStateError, "Cannot set or clear RTS when using RTS or RTS XON/XOFF handshaking")

  if rtsEnabled != port.isRtsEnabled:
    let oldRtsControl = port.dcb.fRtsControl

    port.isRtsEnabled = rtsEnabled
    if rtsEnabled:
      port.dcb.fRtsControl = RTS_CONTROL_ENABLE
    else:
      port.dcb.fRtsControl = RTS_CONTROL_DISABLE

    if SetCommState(Handle(port.handle), addr port.dcb) == 0:
      port.dcb.fRtsControl = oldRtsControl
      port.isRtsEnabled = not rtsEnabled

      raiseOSError(osLastError())

    if EscapeCommFunction(Handle(port.handle), if rtsEnabled: SETRTS else: CLRRTS) == 0:
      raiseOSError(osLastError())

proc `rtsEnable=`*(port: SerialPort | AsyncSerialPort, rtsEnabled: bool) =
  ## Set or clear the ready to send signal.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot change the ready to send signal status whilst the serial port is closed")

  setRtsEnable(port, rtsEnabled)

proc rtsEnable*(port: SerialPort | AsyncSerialPort): bool =
  ## Check whether the ready to send signal is currently set.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the ready to send signal status whilst the serial port is closed")

  let rtsControl = port.dcb.fRtsControl
  if rtsControl == RTS_CONTROL_HANDSHAKE:
    raise newException(InvalidSerialPortStateError, "Cannot manage RTS signal when using RTS or RTS XON/XOFF handshaking")

  result = rtsControl == RTS_CONTROL_ENABLE

proc `handshake=`*(port: SerialPort | AsyncSerialPort, handshake: Handshake) =
  ## Set the handshaking type for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot set the handshaking method whilst the serial port is closed")

  if handshake != port.handshake:
    let oldHandshake = port.handshake
    let oldfInX = port.dcb.fInX
    let oldfOutxCtsFlow = port.dcb.fOutxCtsFlow
    let oldfRtsControl = port.dcb.fRtsControl

    port.handshake = handshake
    let fInX = if handshake in {Handshake.XOnXOff, Handshake.RequestToSendXOnXOff}: DWORD(1) else: DWORD(0)

    port.dcb.fInX = fInX
    port.dcb.fOutX = fInX

    if handshake in {Handshake.RequestToSend, Handshake.RequestToSendXOnXOff}:
      port.dcb.fOutxCtsFlow = DWORD(1)
      port.dcb.fRtsControl = RTS_CONTROL_HANDSHAKE
    elif port.rtsEnable:
      port.dcb.fOutxCtsFlow = DWORD(0)
      port.dcb.fRtsControl = RTS_CONTROL_ENABLE
    else:
      port.dcb.fOutxCtsFlow = DWORD(0)
      port.dcb.fRtsControl = RTS_CONTROL_DISABLE

    if SetCommState(Handle(port.handle), addr port.dcb) == 0:
      port.handshake = oldHandshake
      port.dcb.fInX = oldfInX
      port.dcb.fOutxCtsFlow = oldfOutxCtsFlow
      port.dcb.fRtsControl = oldfRtsControl

      raiseOSError(osLastError())

proc handshake*(port: SerialPort | AsyncSerialPort): Handshake =
  ## Get the handshaking type for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the handshaking method whilst the serial port is closed")

  result = port.handshake

proc initPort(port: SerialPort | AsyncSerialPort, tempHandle: Handle, baudRate: int32, parity: Parity, dataBits: byte, stopBits: StopBits,
              handshaking: Handshake = Handshake.None, readTimeout = TIMEOUT_INFINITE,
              writeTimeout = TIMEOUT_INFINITE, dtrEnable = false, rtsEnable = false) {.inline.} =
  when port is AsyncSerialPort:
    var registered = false

  try:
    let fileType = GetFileType(tempHandle)
    if not (fileType in {DWORD(FileType.Character), DWORD(FileType.Unknown)}):
      raise newException(InvalidSerialPortError, "Serial port '" & port.name & "' is not a valid COM port.")

    when port is AsyncSerialPort:
      port.handle = AsyncFD(tempHandle)
      register(port.handle)
      registered = true
    else:
      port.handle = FileHandle(tempHandle)

    var pinStatus: int32

    if GetCommProperties(tempHandle, addr port.commProp) == 0 or GetCommModemStatus(tempHandle, addr pinStatus) == 0:
      let errorCode = osLastError()
      if int32(errorCode) in {ERROR_INVALID_PARAMETER, ERROR_INVALID_HANDLE}:
        raise newException(InvalidSerialPortError, "Serial port '" & port.name & "' is not a valid COM port.")
      else:
        raiseOSError(errorCode)

    if port.commProp.dwMaxBaud != 0 and baudRate > port.commProp.dwMaxBaud:
      raise newException(InvalidBaudRateError, "Baud rate '" & $baudRate & "' is outside of the valid range allowed by the COM port")

    port.handshake = handshaking

    initDcb(port, baudRate, parity, dataBits, stopBits, handshaking)

    port.setDtrEnable(dtrEnable)
    port.isRtsEnabled = (port.dcb.fRtsControl == RTS_CONTROL_ENABLE)

    if handshaking != Handshake.RequestToSend and handshaking != Handshake.RequestToSendXOnXOff:
      port.setRtsEnable(rtsEnable)

    if GetCommTimeouts(tempHandle, addr port.commTimeouts) == 0:
      raiseOSError(osLastError())

    port.setTimeouts(readTimeout, writeTimeout)

    discard SetCommMask(tempHandle, ALL_EVENTS)
  except:
    when port is AsyncSerialPort:
      if registered:
        unregister(port.handle)

    discard closeHandle(tempHandle)
    port.handle = when port is AsyncSerialPort: AsyncFD(InvalidFileHandle) else: InvalidFileHandle

    raise

proc open*(port: SerialPort, baudRate: int32, parity: Parity, dataBits: byte, stopBits: StopBits,
           handshaking: Handshake = Handshake.None, readTimeout = TIMEOUT_INFINITE,
           writeTimeout = TIMEOUT_INFINITE, dtrEnable = false, rtsEnable = false) =
  ## Open the serial port for reading and writing.
  ##
  ## The `readTimeout` and `writeTimeout` are in milliseconds.
  if port.isOpen():
    raise newException(InvalidSerialPortStateError, "Serial port is already open.")

  let tempHandle = CreateFileWindows(
    getWindowsString("\\\\.\\" & port.name),
    FileAccess,
    FileShareMode, # Open with exclusive access
    nil, # No security attributes
    FileCreationDisposition,
    FileFlagsAndAttributes,
    FileTemplateHandle # hTemplate must be NULL for comm devices
  )

  if tempHandle == INVALID_HANDLE_VALUE:
    raiseOSError(osLastError())

  initPort(port, tempHandle, baudRate, parity, dataBits, stopBits, handshaking, readTimeout, writeTimeout, dtrEnable, rtsEnable)

proc open*(port: AsyncSerialPort, baudRate: int32, parity: Parity, dataBits: byte, stopBits: StopBits,
           handshaking: Handshake = Handshake.None, readTimeout = TIMEOUT_INFINITE,
           writeTimeout = TIMEOUT_INFINITE, dtrEnable = false, rtsEnable = false) =
  ## Open the serial port for reading and writing.
  ##
  ## The `readTimeout` and `writeTimeout` are in milliseconds.
  if port.isOpen():
    raise newException(InvalidSerialPortStateError, "Serial port is already open.")

  let tempHandle = CreateFileWindows(
    getWindowsString("\\\\.\\" & port.name),
    FileAccess,
    FileShareMode, # Open with exclusive access
    nil, # No security attributes
    FileCreationDisposition,
    AsyncFileFlagsAndAttributes,
    FileTemplateHandle # hTemplate must be NULL for comm devices
  )

  if tempHandle == INVALID_HANDLE_VALUE:
    raiseOSError(osLastError())

  initPort(port, tempHandle, baudRate, parity, dataBits, stopBits, handshaking, readTimeout, writeTimeout, dtrEnable, rtsEnable)

proc read*(port: SerialPort, buff: pointer, len: int32): int32 =
  ## Read up to `len` bytes from the serial port into the buffer `buff`. This will return the actual number of bytes that were received.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Port must be open in order to read from it")

  var errors: DWORD
  if ClearCommError(port.handle, addr errors, nil) == 0:
    raiseOSError(osLastError())

  if winlean.readFile(port.handle, buff, len, addr result, nil) == 0:
    raiseOSError(osLastError())

  if result == 0:
    raise newException(TimeoutError, "Read timed out")

proc read*(port: AsyncSerialPort, buff: pointer, len: int32): Future[int32] =
  ## Read up to `len` bytes from the serial port into the buffer `buff`. This will return the actual number of bytes that were received.
  var retFuture = newFuture[int32]("serialport.read")

  if not port.isOpen():
    retFuture.fail(newException(InvalidSerialPortStateError, "Port must be open in order to write to it"))
    return retFuture

  var errors: DWORD
  if ClearCommError(Handle(port.handle), addr errors, nil) == 0:
    retFuture.fail(newException(OSError, osErrorMsg(osLastError())))
    return retFuture

  var ol = PCustomOverlapped()
  GC_ref(ol)
  ol.data = CompletionData(fd: port.handle, cb: proc(fd: AsyncFD, bytesCount: DWORD, errorCode: OSErrorCode) =
    if not retFuture.finished:
      if errorCode == OSErrorCode(-1):
        retFuture.complete(bytesCount)
      elif errorCode == OSErrorCode(ERROR_HANDLE_EOF):
        retFuture.complete(0)
      else:
        retFuture.fail(newException(OSError, osErrorMsg(errorCode)))
  )

  ol.offset = DWORD(0)
  ol.offsetHigh = DWORD(0)

  let ret = winlean.readFile(Handle(port.handle), buff, len, nil, cast[POVERLAPPED](ol))
  if not bool(ret):
    let err = osLastError()
    if int32(err) != ERROR_IO_PENDING:
      GC_unref(ol)
      if int32(err) == ERROR_HANDLE_EOF:
        retFuture.complete(0)
      else:
        retFuture.fail(newException(OSError, osErrorMsg(err)))

  return retFuture

proc write*(port: SerialPort, buff: pointer, len: int32): int32 =
  ## Write up to `len` bytes to the serial port from the buffer `buff`. This will return the number of bytes that were written.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Port must be open in order to write to it")

  var errors: DWORD
  if ClearCommError(port.handle, addr errors, nil) == 0:
    raiseOSError(osLastError())

  if winlean.writeFile(port.handle, buff, len, addr result, nil) == 0:
    raiseOSError(osLastError())

  if result == 0:
    raise newException(TimeoutError, "Write timed out")

proc write*(port: AsyncSerialPort, buff: pointer, len: int32): Future[int32] =
  ## Write up to `len` bytes to the serial port from the buffer `buff`. This will return the number of bytes that were written.
  var retFuture = newFuture[int32]("serialport.write")

  if not port.isOpen():
    retFuture.fail(newException(InvalidSerialPortStateError, "Port must be open in order to write to it"))
    return retFuture

  var errors: DWORD
  if ClearCommError(Handle(port.handle), addr errors, nil) == 0:
    retFuture.fail(newException(OSError, osErrorMsg(osLastError())))
    return retFuture

  var ol = PCustomOverlapped()
  GC_ref(ol)
  ol.data = CompletionData(fd: port.handle, cb: proc(fd: AsyncFD, bytesCount: DWORD, errorCode: OSErrorCode) =
    if not retFuture.finished:
      if errorCode == OSErrorCode(-1):
        retFuture.complete(bytesCount)
      else:
        retFuture.fail(newException(OSError, osErrorMsg(errorCode)))
  )

  ol.offset = DWORD(0)
  ol.offsetHigh = DWORD(0)

  let ret = winlean.writeFile(Handle(port.handle), buff, len, nil, cast[POVERLAPPED](ol))
  if not ret.bool:
    let err = osLastError()
    if err.int32 != ERROR_IO_PENDING:
      GC_unref(ol)
      retFuture.fail(newException(OSError, osErrorMsg(err)))
  else:
    # Request completed immediately.
    var bytesWritten: DWord
    let overlappedRes = getOverlappedResult(Handle(port.handle),
        cast[POverlapped](ol), bytesWritten, false.WinBool)
    if not overlappedRes.bool:
      retFuture.fail(newException(OSError, osErrorMsg(osLastError())))
    else:
      retFuture.complete(bytesWritten)

  return retFuture

proc flush*(port: SerialPort | AsyncSerialPort) =
  ## Flush the buffers for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Port must be open in order to be flushed")

  if FlushFileBuffers(Handle(port.handle)) == 0:
    raiseOSError(osLastError())

proc discardInBuffer(port: SerialPort | AsyncSerialPort) =
  if PurgeComm(Handle(port.handle), PURGE_RXCLEAR or PURGE_RXABORT) == 0:
    raiseOSError(osLastError())

proc discardOutBuffer(port: SerialPort | AsyncSerialPort) =
  if PurgeComm(Handle(port.handle), PURGE_TXCLEAR or PURGE_TXABORT) == 0:
    raiseOSError(osLastError())

proc close*(port: SerialPort | AsyncSerialPort) =
  ## Close the serial port.
  try:
    if port.isOpen():
      # Turn off all events
      discard SetCommMask(Handle(port.handle), 0)

      var skipFlush = false
      if EscapeCommFunction(Handle(port.handle), CLRDTR) == 0:
        let lastError = int32(osLastError())

        if lastError in {ERROR_ACCESS_DENIED, ERROR_BAD_COMMAND, ERROR_DEVICE_REMOVED}:
          skipFlush = true
        else:
          # Unknown error
          raiseOSError(OSErrorCode(lastError))

      if not skipFlush:
        port.flush()
        port.discardInBuffer()
        port.discardOutBuffer()
  finally:
    when port is AsyncSerialPort:
      unregister(port.handle)

    discard closeHandle(Handle(port.handle))
    port.handle = when port is AsyncSerialPort: AsyncFD(InvalidFileHandle) else: InvalidFileHandle
