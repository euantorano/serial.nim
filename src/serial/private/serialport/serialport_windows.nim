## Serial port handling for Windows.

import ./serialport_common, ../ffi/ffi_windows

export serialport_common

import winlean, os

const
  FileAccess: DWORD = DWORD(GENERIC_READ or GENERIC_WRITE)
  FileShareMode: DWORD = DWORD(0)
  FileCreationDisposition: DWORD = DWORD(OPEN_EXISTING)
  FileFlagsAndAttributes: DWORD = DWORD(FILE_ATTRIBUTE_NORMAL)
  FileTemplateHandle: Handle = Handle(0)
  PortErrorEvents = DWORD(CE_FRAME or CE_OVERRUN or CE_RXOVER or CE_PARITY)

type
  SerialPort* = ref SerialPortObj

  SerialPortObj = object
    name*: string
    handshake: Handshake
    handle: Handle
    commProp: CommProp
    comStat: ComStat
    dcb: DCB
    commTimeouts: COMMTIMEOUTS
    dtrEnable: bool
    rtsEnable: bool
    inBreak: bool

proc newSerialPort*(portName: string): SerialPort =
  ## Initialise a new serial port, ready to open.
  if len(portName) < 4 or portName[0..2] != "COM":
    raise newException(InvalidSerialPortError, "Serial port name must start with 'COM' on Windows.")

  result = SerialPort(
    name: portName,
    handle: INVALID_HANDLE_VALUE
  )

proc isOpen*(port: SerialPort): bool =
  ## Check whether the serial port is currently open.
  result = port.handle != INVALID_HANDLE_VALUE

proc initDcb(port: SerialPort, baudRate: int32, parity: Parity, dataBits: byte, stopBits: StopBits, handshaking: Handshake) =
  if GetCommState(port.handle, addr port.dcb) == 0:
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
  else:
    raise newException(InvalidStopBitsError, "Invalid number of stop bits '" & $stopBits & "'")

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

  if SetCommState(port.handle, addr port.dcb) == 0:
    raiseOSError(osLastError())

proc getTimeouts*(port: SerialPort): tuple[readTimeout: int32, writeTimeout: int32] =
  ## Get the read and write timeouts for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get timeouts whilst the serial port is closed")

  result = (
    readTimeout: if port.commTimeouts.ReadTotalTimeoutConstant == -2: TIMEOUT_INFINITE else: port.commTimeouts.ReadTotalTimeoutConstant,
    writeTimeout: if port.commTimeouts.WriteTotalTimeoutConstant == 0: TIMEOUT_INFINITE else: port.commTimeouts.WriteTotalTimeoutConstant
  )

proc setTimeouts*(port: SerialPort, readTimeout: int32, writeTimeout: int32) =
  ## Set the read and write timeouts for the serial port.
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

  if SetCommTimeouts(port.handle, addr port.commTimeouts) == 0:
    port.commTimeouts.ReadTotalTimeoutConstant = oldReadTotalTimeoutConstant
    port.commTimeouts.ReadTotalTimeoutMultiplier = oldReadTotalTimeoutMultiplier
    port.commTimeouts.ReadIntervalTimeout = oldReadIntervalTimeout
    port.commTimeouts.WriteTotalTimeoutMultiplier = oldWriteTotalTimeoutMultiplier
    port.commTimeouts.WriteTotalTimeoutConstant = oldWriteTotalTimeoutConstant

    raiseOSError(osLastError())

proc isCarrierHolding*(port: SerialPort): bool =
  ## Check whether the carrier signal is currently active.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot check the carrier signal whilst the serial port is closed")

  var pinStatus: int32
  if GetCommModemStatus(port.handle, addr pinStatus) == 0:
    raiseOSError(osLastError())

  result = (pinStatus and MS_RLSD_ON) != 0

proc isCtsHolding*(port: SerialPort): bool =
  ## Check whether the clear to send signal is currently active.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot check the clear to send signal whilst the serial port is closed")

  var pinStatus: int32
  if GetCommModemStatus(port.handle, addr pinStatus) == 0:
    raiseOSError(osLastError())

  result = (pinStatus and MS_CTS_ON) != 0

proc isDsrHolding*(port: SerialPort): bool =
  ## Check whether the data set ready signal is currently active.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot check the data set ready signal whilst the serial port is closed")

  var pinStatus: int32
  if GetCommModemStatus(port.handle, addr pinStatus) == 0:
    raiseOSError(osLastError())

  result = (pinStatus and MS_DSR_ON) != 0

proc isRingHolding*(port: SerialPort): bool =
  ## Check whether the ring signal is currently active.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot check the ring signal whilst the serial port is closed")

  var pinStatus: int32
  if GetCommModemStatus(port.handle, addr pinStatus) == 0:
    raiseOSError(osLastError())

  result = (pinStatus and MS_RING_ON) != 0

proc `stopBits=`*(port: SerialPort, stopBits: StopBits) =
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
  else:
    raise newException(InvalidStopBitsError, "Invalid number of stop bits '" & $stopBits & "'")

  if stopBitsNative != port.dcb.StopBits:
    let oldStopBits = port.dcb.StopBits
    port.dcb.StopBits = stopBitsNative

    if SetCommState(port.handle, addr port.dcb) == 0:
      port.dcb.StopBits = oldStopBits
      raiseOSError(osLastError())

proc stopBits*(port: SerialPort): StopBits =
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

proc `dataBits=`*(port: SerialPort, dataBits: byte) =
  ## Set the number of data bits for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot set the data bits whilst the serial port is closed")

  if dataBits != port.dcb.ByteSize:
    let oldDataBits = port.dcb.ByteSize
    port.dcb.ByteSize = dataBits

    if SetCommState(port.handle, addr port.dcb) == 0:
      port.dcb.ByteSize = oldDataBits
      raiseOSError(osLastError())

proc dataBits*(port: SerialPort): byte =
  ## Get the number of data bits for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the data bits whilst the serial port is closed")

  result = port.dcb.ByteSize

proc `baudRate=`*(port: SerialPort, baudRate: int32) =
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

    if SetCommState(port.handle, addr port.dcb) == 0:
      port.dcb.BaudRate = oldBaudRate
      raiseOSError(osLastError())

proc baudRate*(port: SerialPort): int32 =
  ## Get the current baud rate for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the baud rate whilst the serial port is closed")

  result = port.dcb.BaudRate

proc `parity=`*(port: SerialPort, parity: Parity) =
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

    if SetCommState(port.handle, addr port.dcb) == 0:
      port.dcb.Parity = oldParity
      port.dcb.fParity = oldFParity
      port.dcb.ErrorChar = oldErrorChar
      port.dcb.fErrorChar = oldfErrorChar

      raiseOSError(osLastError())

proc parity*(port: SerialPort): Parity =
  ## Get the parity for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the parity whilst the serial port is closed")

  result = Parity(port.dcb.Parity)

proc `breakStatus=`*(port: SerialPort, shouldBreak: bool) =
  ## Set the break state on the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot break whilst the serial port is closed")

  if shouldBreak:
    if SetCommBreak(port.handle) == 0:
      raiseOSError(osLastError())

    port.inBreak = true
  else:
    if ClearCommBreak(port.handle) == 0:
      raiseOSError(osLastError())

    port.inBreak = false

proc breakStatus*(port: SerialPort): bool =
  ## Get whether the serial port is currently in a break state.
  ##
  ## This isn't currently implemented in the posix version.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get break whilst the serial port is closed")

  result = port.inBreak

proc `dtrEnable=`*(port: SerialPort, dtrEnabled: bool) =
  ## Set or clear the data terminal ready signal.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot change the data terminal ready signal status whilst the serial port is closed")

  let currentDtrControl = port.dcb.fDtrControl
  port.dcb.fDtrControl = if dtrEnabled: DTR_CONTROL_ENABLE else: DTR_CONTROL_DISABLE
  if SetCommState(port.handle, addr port.dcb) == 0:
    port.dcb.fDtrControl = currentDtrControl
    raiseOSError(osLastError())

  # Now set the actual pin
  if EscapeCommFunction(port.handle, if dtrEnabled: SETDTR else: CLRDTR) == 0:
    raiseOSError(osLastError())

proc dtrEnable*(port: SerialPort): bool =
  ## Check whether the data terminal ready signal is currently set.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the data terminal ready signal status whilst the serial port is closed")

  result = port.dcb.fDtrControl == DTR_CONTROL_ENABLE

proc `rtsEnable=`*(port: SerialPort, rtsEnabled: bool) =
  ## Set or clear the ready to send signal.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot change the ready to send signal status whilst the serial port is closed")

  if port.handshake in {Handshake.RequestToSend, Handshake.RequestToSendXOnXOff}:
    raise newException(InvalidSerialPortStateError, "Cannot set or clear RTS when using RTS or RTS XON/XOFF handshaking")

  if rtsEnabled != port.rtsEnable:
    let oldRtsControl = port.dcb.fRtsControl

    port.rtsEnable = rtsEnabled
    if rtsEnabled:
      port.dcb.fRtsControl = RTS_CONTROL_ENABLE
    else:
      port.dcb.fRtsControl = RTS_CONTROL_DISABLE

    if SetCommState(port.handle, addr port.dcb) == 0:
      port.dcb.fRtsControl = oldRtsControl
      port.rtsEnable = not rtsEnabled

      raiseOSError(osLastError())

    if EscapeCommFunction(port.handle, if rtsEnabled: SETRTS else: CLRRTS) == 0:
      raiseOSError(osLastError())

proc rtsEnable*(port: SerialPort): bool =
  ## Check whether the ready to send signal is currently set.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the ready to send signal status whilst the serial port is closed")

  let rtsControl = port.dcb.fRtsControl
  if rtsControl == RTS_CONTROL_HANDSHAKE:
    raise newException(InvalidSerialPortStateError, "Cannot manage RTS signal when using RTS or RTS XON/XOFF handshaking")

  result = rtsControl == RTS_CONTROL_ENABLE

proc `handshake=`*(port: SerialPort, handshake: Handshake) =
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

    if SetCommState(port.handle, addr port.dcb) == 0:
      port.handshake = oldHandshake
      port.dcb.fInX = oldfInX
      port.dcb.fOutxCtsFlow = oldfOutxCtsFlow
      port.dcb.fRtsControl = oldfRtsControl

      raiseOSError(osLastError())

proc handshake*(port: SerialPort): Handshake =
  ## Get the handshaking type for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Cannot get the handshaking method whilst the serial port is closed")

  result = port.handshake

proc open*(port: SerialPort, baudRate: int32, parity: Parity, dataBits: byte, stopBits: StopBits,
           handshaking: Handshake = Handshake.None, readTimeout = TIMEOUT_INFINITE,
           writeTimeout = TIMEOUT_INFINITE, dtrEnable = false) =
  ## Open the serial port for reading and writing.
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

  try:
    let fileType = GetFileType(tempHandle)
    if not (fileType in {DWORD(FileType.Character), DWORD(FileType.Unknown)}):
      raise newException(InvalidSerialPortError, "Serial port '" & port.name & "' is not a valid COM port.")

    port.handle = tempHandle

    var pinStatus: int32

    if GetCommProperties(port.handle, addr port.commProp) == 0 or GetCommModemStatus(port.handle, addr pinStatus) == 0:
      let errorCode = osLastError()
      if int32(errorCode) in {ERROR_INVALID_PARAMETER, ERROR_INVALID_HANDLE}:
        raise newException(InvalidSerialPortError, "Serial port '" & port.name & "' is not a valid COM port.")
      else:
        raiseOSError(errorCode)

    if port.commProp.dwMaxBaud != 0 and baudRate > port.commProp.dwMaxBaud:
      raise newException(InvalidBaudRateError, "Baud rate '" & $baudRate & "' is outside of the valid range allowed by the COM port")

    port.handshake = handshaking

    initDcb(port, baudRate, parity, dataBits, stopBits, handshaking)

    port.dtrEnable = dtrEnable
    port.rtsEnable = (port.dcb.fRtsControl == RTS_CONTROL_ENABLE)

    if handshaking != Handshake.RequestToSend and handshaking != Handshake.RequestToSendXOnXOff:
      # TODO: Set the RTS enable flag
      discard

    if GetCommTimeouts(port.handle, addr port.commTimeouts) == 0:
      raiseOSError(osLastError())
      
    port.setTimeouts(readTimeout, writeTimeout)

    discard SetCommMask(port.handle, ALL_EVENTS)
  except:
    discard closeHandle(tempHandle)
    port.handle = INVALID_HANDLE_VALUE
    raise

proc checkErrors(port: SerialPort, errors: DWORD) {.inline.} =
  if (errors and PortErrorEvents) != 0:
    if (errors and CE_RXOVER) != 0:
      #port.eventEmitter.emit(port.errorReceived, ErrorReceivedEventArgs(errorType: ReceivedError.ReceiveOverflow))
      echo "[ERROR] Receive overflow"

    if (errors and CE_OVERRUN) != 0:
      #port.eventEmitter.emit(port.errorReceived, ErrorReceivedEventArgs(errorType: ReceivedError.Overrun))
      echo "[ERROR] Overrun"

    if (errors and CE_PARITY) != 0:
      #port.eventEmitter.emit(port.errorReceived, ErrorReceivedEventArgs(errorType: ReceivedError.Parity))
      echo "[ERROR] RxParity"

    if (errors and CE_FRAME) != 0:
      #port.eventEmitter.emit(port.errorReceived, ErrorReceivedEventArgs(errorType: ReceivedError.Framing))
      echo "[ERROR] Frame"

proc read*(port: SerialPort, buff: pointer, len: int32): int32 =
  ## Read up to `len` bytes from the serial port into the buffer `buff`. This will return the actual number of bytes that were received.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Port must be open in order to read from it")

  var errors: DWORD
  if ClearCommError(port.handle, addr errors, nil) == 0:
    raiseOSError(osLastError())

  port.checkErrors(errors)

  if winlean.readFile(port.handle, buff, len, addr result, nil) == 0:
    raiseOSError(osLastError())

  if result == 0:
    raise newException(TimeoutError, "Read timed out")

proc write*(port: SerialPort, buff: pointer, len: int32): int32 =
  ## Write up to `len` bytes to the serial port from the buffer `buff`. This will return the number of bytes that were written.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Port must be open in order to write to it")

  var errors: DWORD
  if ClearCommError(port.handle, addr errors, nil) == 0:
    raiseOSError(osLastError())

  port.checkErrors(errors)

  if winlean.writeFile(port.handle, buff, len, addr result, nil) == 0:
    raiseOSError(osLastError())

  if result == 0:
    raise newException(TimeoutError, "Write timed out")

proc flush*(port: SerialPort) =
  ## Flush the buffers for the serial port.
  if not port.isOpen():
    raise newException(InvalidSerialPortStateError, "Port must be open in order to be flushed")

  if FlushFileBuffers(port.handle) == 0:
    raiseOSError(osLastError())

proc discardInBuffer(port: SerialPort) =
  if PurgeComm(port.handle, PURGE_RXCLEAR or PURGE_RXABORT) == 0:
    raiseOSError(osLastError())

proc discardOutBuffer(port: SerialPort) =
  if PurgeComm(port.handle, PURGE_TXCLEAR or PURGE_TXABORT) == 0:
    raiseOSError(osLastError())

proc close*(port: SerialPort) =
  ## Close the serial port.
  try:
    if port.isOpen():
      # Turn off all events
      discard SetCommMask(port.handle, 0)

      var skipFlush = false
      if EscapeCommFunction(port.handle, CLRDTR) == 0:
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
    discard closeHandle(port.handle)
    port.handle = INVALID_HANDLE_VALUE
