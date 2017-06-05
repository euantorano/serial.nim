## A library to work with serial ports using pure Nim.

include libserialport/private/list_serialports, libserialport/private/common

when defined(nimdoc):
  proc openSerialPort*(name: string, baudRate: BaudRate = BaudRate.BR9600,
      dataBits: DataBits = DataBits.eight, parity: Parity = Parity.none,
      stopBits: StopBits = StopBits.one, useHardwareFlowControl: bool = false,
      useSoftwareFlowControl: bool = false): SerialPort {.raises: [InvalidPortNameError, ParityUnknownError, OSError].} = discard
    ## Open the serial port with the given name.
    ##
    ## If the serial port at the given path is not found, a `InvalidPortNameError` will be raised.

  proc isClosed*(port: SerialPort): bool = discard
    ## Determine whether the given port is open or closed.

  proc close*(port: SerialPort) {.raises: [OSError].} = discard
    ## Close the seial port, restoring its original settings.

  proc `baudRate=`*(port: SerialPort, br: BaudRate) {.raises: [PortClosedError, OSError].} = discard
    ## Set the baud rate that the serial port operates at.

  proc baudRate*(port: SerialPort): BaudRate {.raises: [PortClosedError, BaudRateUnknownError, OSError].} = discard
    ## Get the baud rate that the serial port is currently operating at.

  proc `dataBits=`*(port: SerialPort, db: DataBits) {.raises: [PortClosedError, OSError].} = discard
    ## Set the number of data bits that the serial port operates with.

  proc dataBits*(port: SerialPort): DataBits {.raises: [PortClosedError, OSError].} = discard
    ## Get the number of data bits that the serial port operates with.

  proc `parity=`*(port: SerialPort, parity: Parity) {.raises: [PortClosedError, ParityUnknownError, OSError].} = discard
    ## Set the parity that the serial port operates with.

  proc parity*(port: SerialPort): Parity {.raises: [PortClosedError, ParityUnknownError, OSError].} = discard
    ## Get the parity that the serial port operates with.

  proc `stopBits=`*(port: SerialPort, sb: StopBits) {.raises: [PortClosedError, OSError].} = discard
    ## Set the number of stop bits that the serial port operates with.

  proc stopBits*(port: SerialPort): StopBits {.raises: [PortClosedError, StopBitsUnknownError, OSError].} = discard
    ## Get the number of stop bits that the serial port operates with.

  proc `hardwareFlowControl=`*(port: SerialPort, enabled: bool) {.raises: [PortClosedError, OSError].} = discard
    ## Set whether to use RTS and CTS flow control for sending/receiving data with the serial port.

  proc hardwareFlowControl*(port: SerialPort): bool {.raises: [PortClosedError, OSError].} = discard
    ## Get whether RTS/CTS is enabled for the serial port.

  proc `softwareFlowControl=`*(port: SerialPort, enabled: bool) {.raises: [PortClosedError, OSError].} = discard
    ## Set whether to use XON/XOFF software flow control for sending/receiving data with the serial port.

  proc softwareFlowControl*(port: SerialPort): bool {.raises: [PortClosedError, OSError].} = discard
    ## Get whether XON?XOFF software flow control is enabled for the serial port.

  proc write*(port: SerialPort, data: pointer, length: int, timeout: uint = 0): int {.raises: [PortClosedError, PortTimeoutError, OSError], tags: [WriteIOEffect].} =
    ## Write the data in the buffer pointed to by `data` with the given `length` to the serial port.

  proc write*(port: SerialPort, data: string, timeout: uint = 0) {.raises: [PortClosedError, PortTimeoutError, OSError], tags: [WriteIOEffect].} = discard
    ## Write `data` to the serial port. This ensures that all of `data` is written.

  proc read*(port: SerialPort, data: pointer, size: int, timeout: uint = 0): int
    {.raises: [PortClosedError, PortTimeoutError, OSError], tags: [ReadIOEffect].} = discard
    ## Read from the serial port into the buffer pointed to by `data`, with buffer length `size`.
    ##
    ## This will return the number of bytes received, as it does not guarantee that the buffer will be filled completely.
    ##
    ## The read will time out after `timeout` seconds if no data is received in that time.
    ## To disable timeouts, pass `0` as the timeout parameter. When timeouts are disabled, this will block until at least 1 byte of data is received.
elif defined(posix):
  include libserialport/private/serial_posix
elif defined(windows):
  include libserialport/private/serial_windows
else:
  {.error: "Serial port handling not implemented for your platform".}
