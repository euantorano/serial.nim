# Windows implementation of serial port handling.

import winlean, os

type
  DCB {.importc: "DCB", header: "<windows.h>".} = object
    DCBlength: DWORD
    BaudRate: DWORD
    fBinary {.bitsize: 1.}: DWORD
    fParity {.bitsize: 1.}: DWORD
    fOutxCtsFlow {.bitsize: 1.}: DWORD
    fOutxDsrFlow {.bitsize: 1.}: DWORD
    fDtrControl {.bitsize: 2.}: DWORD
    fDsrSensitivity {.bitsize: 1.}: DWORD
    fTXContinueOnXoff {.bitsize: 1.}: DWORD
    fOutX {.bitsize: 1.}: DWORD
    fInX {.bitsize: 1.}: DWORD
    fErrorChar {.bitsize: 1.}: DWORD
    fNull {.bitsize: 1.}: DWORD
    fRtsControl {.bitsize: 2.}: DWORD
    fAbortOnError {.bitsize: 1.}: DWORD
    fDummy2 {.bitsize: 17.}: DWORD
    ByteSize: byte
    Parity: byte
    StopBits: byte

  COMMTIMEOUTS {.importc: "COMMTIMEOUTS", header: "<windows.h>".} = object
    ReadIntervalTimeout: DWORD
    ReadTotalTimeoutMultiplier: DWORD
    ReadTotalTimeoutConstant: DWORD
    WriteTotalTimeoutMultiplier: DWORD
    WriteTotalTimeoutConstant: DWORD

proc GetCommState(h: HANDLE, lpDCB: ptr DCB): bool {.importc: "GetCommState",
    header: "<windows.h>".}

proc SetCommState(h: HANDLE, lpDCB: ptr DCB): bool {.importc: "SetCommState",
    header: "<windows.h>".}

proc GetCommTimeouts (h: HANDLE, lpCommTimeouts: ptr COMMTIMEOUTS): bool {.importc: "GetCommTimeouts ",
    header: "<windows.h>".}

proc SetCommTimeouts(h: HANDLE, lpCommTimeouts: ptr COMMTIMEOUTS): bool {.importc: "SetCommTimeouts",
    header: "<windows.h>".}

proc setBaudRate(options: var DCB, br: BaudRate) =
  ## Set the baud rate on the given `Termios` instance.
  options.BaudRate = DWORD(br)

proc setDataBits(options: var DCB, db: DataBits) =
  ## Set the number of data bits on the given `Termios` instance.
  options.ByteSize = byte(db)

proc setParity(options: var DCB, parity: Parity) =
  ## Set the parity on the given `Termios` instance.
  case parity
  of Parity.none:
    options.Parity = byte(0)
  of Parity.odd:
    options.Parity = byte(1)
  of Parity.even:
    options.Parity = byte(2)
  of Parity.mark:
    options.Parity = byte(3)
  of Parity.space:
    options.Parity = byte(4)

proc setStopBits(options: var DCB, sb: StopBits) =
  ## Set the number of stop bits on the given `Termios` instance.
  case sb
  of StopBits.one:
    options.StopBits = byte(0)
  of StopBits.onePointFive:
    options.StopBits = byte(1)
  of StopBits.two:
    options.StopBits = byte(2)

proc setHardwareFlowControl(options: var DCB, enabled: bool) =
  ## Set whether to use CTS/RTS flow control.
  # Enable RTS handshaking - there are other options, but are they needed?
  if enabled:
    options.fRtsControl = 2
    options.fOutxCtsFlow = 1
  else:
    options.fRtsControl = 0
    options.fOutxCtsFlow = 0

proc setSoftwareFlowControl(options: var DCB, enabled: bool) =
  ## Set whether to use XON/XOFF software flow control.
  if enabled:
    options.fOutX = 1
    options.fInX = 1
  else:
    options.fOutX = 0
    options.fInX = 0

proc setWriteTimeout(port: SerialPort, timeout: uint) {.raises: [OSError].} =
  ## Set the write timeout from the given serial port.
  var timeouts: COMMTIMEOUTS

  if not GetCommTimeouts(port.handle, addr timeouts):
    raiseOSError(osLastError())

  timeouts.WriteTotalTimeoutConstant = DWORD(timeout * 1000)
  timeouts.WriteTotalTimeoutMultiplier = 0

  if not SetCommTimeouts(port.handle, addr timeouts):
    raiseOSError(osLastError())

  port.writeTimeoutSeconds = timeout

proc setReadTimeout(port: SerialPort, timeout: uint) {.raises: [OSError].} =
  ## Set the write timeout for the given serial port.
  var timeouts: COMMTIMEOUTS

  if not GetCommTimeouts(port.handle, addr timeouts):
    raiseOSError(osLastError())

  if timeout == 0'u:
    # No timeout, wait until some data is received and read up until the buffer size or 10ms between bytes
    timeouts.ReadIntervalTimeout = 10
    timeouts.ReadTotalTimeoutConstant = 0
    timeouts.ReadTotalTimeoutMultiplier = 0
  else:
    timeouts.ReadTotalTimeoutConstant = DWORD(timeout * 1000)
    timeouts.ReadIntervalTimeout = 0
    timeouts.ReadTotalTimeoutMultiplier = 0

  if not SetCommTimeouts(port.handle, addr timeouts):
    raiseOSError(osLastError())

  port.readTimeoutSeconds = timeout

proc openSerialPort*(name: string, baudRate: BaudRate = BaudRate.BR9600,
    dataBits: DataBits = DataBits.eight, parity: Parity = Parity.none,
    stopBits: StopBits = StopBits.one, useHardwareFlowControl: bool = false,
    useSoftwareFlowControl: bool = false): SerialPort {.raises: [OSError].} =
  ## Open the serial port with the given name.
  ##
  ## If the serial port at the given path is not found, a `InvalidPortNameError` will be raised.
  let portName: string = if len(name) == 4 and name[3] in {'0'..'9'}: name else: r"\\\\.\\" & name

  when useWinUnicode:
    let h = createFileW(newWideCString(portName), DWORD(GENERIC_READ or GENERIC_WRITE),
      DWORD(0), nil, DWORD(OPEN_EXISTING), DWORD(FILE_ATTRIBUTE_NORMAL), 0.HANDLE)
  else:
    let h = createFileA(portName.cstring, DWORD(GENERIC_READ or GENERIC_WRITE),
      DWORD(0), nil, DWORD(OPEN_EXISTING), DWORD(FILE_ATTRIBUTE_NORMAL), 0.HANDLE)

  if h == INVALID_HANDLE_VALUE:
    raiseOSError(osLastError())

  var serialParams: DCB

  if not GetCommState(h, addr serialParams):
    discard closeHandle(h)
    raiseOSError(osLastError())

  setBaudRate(serialParams, baudRate)
  setDataBits(serialParams, dataBits)
  setStopBits(serialParams, stopBits)
  setParity(serialParams, parity)
  setHardwareFlowControl(serialParams, useHardwareFlowControl)
  setSoftwareFlowControl(serialParams, useSoftwareFlowControl)

  if not SetCommState(h, addr serialParams):
    discard closeHandle(h)
    raiseOSError(osLastError())

  result = SerialPort(
    name: name,
    handle: h
  )

  try:
    setReadTimeout(result, 0)
    setWriteTimeout(result, 0)
  except:
    discard closeHandle(h)
    raise

proc isClosed*(port: SerialPort): bool = port.handle == INVALID_HANDLE_VALUE
  ## Determine whether the given port is open or closed.

proc close*(port: SerialPort) {.raises: [OSError].} =
  ## Close the seial port, restoring its original settings.
  if closeHandle(port.handle) == 0:
    raiseOSError(osLastError())

  port.handle = INVALID_HANDLE_VALUE

template checkPortIsNotClosed(port: SerialPort) =
  if port.isClosed:
    raise newException(PortClosedError, "Port '" & port.name & "' is closed")

proc `baudRate=`*(port: SerialPort, br: BaudRate) {.raises: [PortClosedError, OSError].} =
  ## Set the baud rate that the serial port operates at.
  checkPortIsNotClosed(port)

  var options: DCB
  if not GetCommState(port.handle, addr options):
    raiseOSError(osLastError())

  setBaudRate(options, br)

  if not SetCommState(port.handle, addr options):
    raiseOSError(osLastError())

proc baudRate*(port: SerialPort): BaudRate {.raises: [PortClosedError, OSError].} =
  ## Get the baud rate that the serial port is currently operating at.
  checkPortIsNotClosed(port)

  var options: DCB
  if not GetCommState(port.handle, addr options):
    raiseOSError(osLastError())

  result = BaudRate(options.BaudRate)

proc `dataBits=`*(port: SerialPort, db: DataBits) {.raises: [PortClosedError, OSError].} =
  ## Set the number of data bits that the serial port operates with.
  checkPortIsNotClosed(port)

  var options: DCB
  if not GetCommState(port.handle, addr options):
    raiseOSError(osLastError())

  setDataBits(options, db)

  if not SetCommState(port.handle, addr options):
    raiseOSError(osLastError())

proc dataBits*(port: SerialPort): DataBits {.raises: [PortClosedError, OSError].} =
  ## Get the number of data bits that the serial port operates with.
  checkPortIsNotClosed(port)

  var options: DCB
  if not GetCommState(port.handle, addr options):
    raiseOSError(osLastError())

  result = DataBits(options.ByteSize)

proc `parity=`*(port: SerialPort, parity: Parity) {.raises: [PortClosedError, OSError].} =
  ## Set the parity that the serial port operates with.
  checkPortIsNotClosed(port)

  var options: DCB
  if not GetCommState(port.handle, addr options):
    raiseOSError(osLastError())

  setParity(options, parity)

  if not SetCommState(port.handle, addr options):
    raiseOSError(osLastError())

proc parity*(port: SerialPort): Parity {.raises: [PortClosedError, ParityUnknownError, OSError].} =
  ## Get the parity that the serial port operates with.
  checkPortIsNotClosed(port)

  var options: DCB
  if not GetCommState(port.handle, addr options):
    raiseOSError(osLastError())

  case options.Parity
  of 0:
    result = Parity.none
  of 1:
    result = Parity.odd
  of 2:
    result = Parity.even
  of 3:
    result = Parity.mark
  of 4:
    result = Parity.space
  else:
    raise newException(ParityUnknownError, "Unknown parity: " & $options.Parity)

proc `stopBits=`*(port: SerialPort, sb: StopBits) {.raises: [PortClosedError, OSError].} =
  ## Set the number of stop bits that the serial port operates with.
  checkPortIsNotClosed(port)

  var options: DCB
  if not GetCommState(port.handle, addr options):
    raiseOSError(osLastError())

  setStopBits(options, sb)

  if not SetCommState(port.handle, addr options):
    raiseOSError(osLastError())

proc stopBits*(port: SerialPort): StopBits {.raises: [PortClosedError, StopBitsUnknownError, OSError].} =
  ## Get the number of stop bits that the serial port operates with.
  checkPortIsNotClosed(port)

  var options: DCB
  if not GetCommState(port.handle, addr options):
    raiseOSError(osLastError())

  case options.StopBits
  of 0:
    result = StopBits.one
  of 1:
    result = StopBits.onePointFive
  of 2:
    result = StopBits.two
  else:
    raise newException(StopBitsUnknownError, "unknown number of stop bits: " & $options.StopBits)

proc `hardwareFlowControl=`*(port: SerialPort, enabled: bool) {.raises: [PortClosedError, OSError].} =
  ## Set whether to use RTS and CTS flow control for sending/receiving data with the serial port.
  checkPortIsNotClosed(port)

  var options: DCB
  if not GetCommState(port.handle, addr options):
    raiseOSError(osLastError())

  setHardwareFlowControl(options, enabled)

  if not SetCommState(port.handle, addr options):
    raiseOSError(osLastError())

proc hardwareFlowControl*(port: SerialPort): bool {.raises: [PortClosedError, OSError].} =
  ## Get whether RTS/CTS is enabled for the serial port.
  checkPortIsNotClosed(port)

  var options: DCB
  if not GetCommState(port.handle, addr options):
    raiseOSError(osLastError())

  result = options.fRtsControl != 0 and options.fOutxCtsFlow != 0

proc `softwareFlowControl=`*(port: SerialPort, enabled: bool) {.raises: [PortClosedError, OSError].} =
  ## Set whether to use XON/XOFF software flow control for sending/receiving data with the serial port.
  checkPortIsNotClosed(port)

  var options: DCB
  if not GetCommState(port.handle, addr options):
    raiseOSError(osLastError())

  setSoftwareFlowControl(options, enabled)

  if not SetCommState(port.handle, addr options):
    raiseOSError(osLastError())

proc softwareFlowControl*(port: SerialPort): bool {.raises: [PortClosedError, OSError].} =
  ## Get whether XON?XOFF software flow control is enabled for the serial port.
  checkPortIsNotClosed(port)

  var options: DCB
  if not GetCommState(port.handle, addr options):
    raiseOSError(osLastError())

  result = options.fOutX != 0 and options.fInX != 0

proc write*(port: SerialPort, data: pointer, length: int, timeout: uint = 0): int {.raises: [PortClosedError, PortTimeoutError, OSError], tags: [WriteIOEffect].} =
  ## Write the data in the buffer pointed to by `data` with the given `length` to the serial port.
  checkPortIsNotClosed(port)

  # if the last write operation used the same timeout, do not change the timeout.
  if timeout != port.writeTimeoutSeconds:
    setWriteTimeout(port, timeout)

  var numWritten: int32
  if writeFile(port.handle, data[totalWritten].unsafeAddr, dataLen - totalWritten, addr numWritten, nil) == 0:
    raiseOSError(osLastError())

  if numWritten == 0:
    raise newException(PortTimeoutError, "Write timed out after " & $timeout & " seconds")

  result = int(numWritten)

proc write*(port: SerialPort, data: cstring, timeout: uint = 0) {.raises: [PortClosedError, PortTimeoutError, OSError], tags: [WriteIOEffect].} =
  ## Write `data` to the serial port. This ensures that all of `data` is written.
  ##
  ## You can optionally set a timeout (in seconds) for the write operation by passing a non-zero `timeout` value.
  checkPortIsNotClosed(port)

  # if the last write operation used the same timeout, do not change the timeout.
  if timeout != port.writeTimeoutSeconds:
    setWriteTimeout(port, timeout)

  let dataLen: int32 = int32(len(data))

  var
    totalWritten: int32 = 0
    numWritten: int32
  while totalWritten < len(data):
    if writeFile(port.handle, data[totalWritten].unsafeAddr, dataLen - totalWritten, addr numWritten, nil) == 0:
      raiseOSError(osLastError())

    if numWritten == 0:
      raise newException(PortTimeoutError, "Write timed out after " & $timeout & " seconds")

    inc(totalWritten, numWritten)

proc read*(port: SerialPort, data: pointer, size: int, timeout: uint = 0): int
  {.raises: [PortClosedError, PortTimeoutError, OSError], tags: [ReadIOEffect].} =
  ## Read from the serial port into the buffer pointed to by `data`, with buffer length `size`.
  ##
  ## This will return the number of bytes received, as it does not guarantee that the buffer will be filled completely.
  ##
  ## The read will time out after `timeout` seconds if no data is received in that time.
  ## To disable timeouts, pass `0` as the timeout parameter. When timeouts are disabled, this will block until at least 1 byte of data is received.
  checkPortIsNotClosed(port)

  # if the last read operation used the same timeout, do not change the timeout.
  if timeout != port.readTimeoutSeconds:
    setReadTimeout(port, timeout)

  var numBytesRead: int32
  if readFile(port.handle, data, int32(size), addr numBytesRead, nil) == 0:
    raiseOSError(osLastError())

  if numBytesRead == 0 and timeout != 0:
    raise newException(PortTimeoutError, "Read timed out after " & $timeout & " seconds")

  result = int(numBytesRead)
