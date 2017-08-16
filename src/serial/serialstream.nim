## A stream type to work with serial ports.

import streams

import ./serialport

const
  BufferSize*: int = 4000
    ## Size of a buffered serialport stream's buffer

type
  SerialStream* = ref SerialStreamObj
    ## A stream that encapsulates a `SerialPort`

  SerialStreamObj = object of Stream
    port: SerialPort
    case isBuffered: bool # determines whether this stream is buffered
    of true:
      buffer: array[0..BufferSize, char]
      currPos: int # current index in buffer
      bufLen: int # current length of buffer
    of false: nil

proc spClose(s: Stream) =
  if SerialStream(s).port != nil:
    close(SerialStream(s).port)
    SerialStream(s).port = nil

proc spAtEnd(s: Stream): bool =
  result = not isOpen(SerialStream(s).port)

proc spSetPosition(s: Stream, pos: int) = discard

proc spGetPosition(s: Stream): int = 0

proc readIntoBuf(s: SerialStream): int =
  result = read(s.port, addr(s.buffer), int32(high(s.buffer)))
  if result <= 0:
    s.bufLen = 0
    s.currPos = 0
    return result
  s.bufLen = result
  s.currPos = 0

template retRead(readBytes: int) {.dirty.} =
  let res = SerialStream(s).readIntoBuf()
  if res <= 0:
    if readBytes > 0:
      return readBytes
    else:
      return res

proc spReadData(s: Stream, buffer: pointer, bufLen: int): int =
  let serialStream = SerialStream(s)

  if serialStream.isBuffered:
    if serialStream.bufLen == 0:
      retRead(0)

    var read = 0
    while read < bufLen:
      if serialStream.currPos >= serialStream.bufLen:
        retRead(read)

      let chunk = min(serialStream.bufLen - serialStream.currPos, bufLen - read)
      var d = cast[cstring](buffer)
      assert bufLen - read >= chunk
      copyMem(addr d[read], addr serialStream.buffer[serialStream.currPos], chunk)
      read.inc(chunk)
      serialStream.currPos.inc(chunk)

    result = read
  else:
    result = int(SerialStream(s).port.read(buffer, int32(bufLen)))

proc spPeekData(s: Stream, buffer: pointer, bufLen: int): int =
  if SerialStream(s).isBuffered:
    let serialStream = SerialStream(s)

    if serialStream.currPos < serialStream.bufLen:
      let numAvailable = serialStream.bufLen - serialStream.currPos
      result = min(numAvailable, bufLen)

      var d = cast[cstring](buffer)
      copyMem(addr d[0], addr serialStream.buffer[serialStream.currPos], result)
    else:
      result = 0
  else:
    result = 0

proc spWriteData(s: Stream, buffer: pointer, bufLen: int) =
  let toWrite = int32(bufLen)

  var
    mutBuffer = buffer
    numWritten: int32
    totalWritten: int32 = 0

  while totalWritten < toWrite:
    numWritten = SerialStream(s).port.write(mutBuffer, toWrite - totalWritten)

    mutBuffer = cast[pointer](cast[int](mutBuffer) + numWritten)
    inc(totalWritten, numWritten)

proc spFlush(s: Stream) =
  SerialStream(s).port.flush()

proc newSerialStream*(p: SerialPort, buffered = false): SerialStream =
  ## Creates a new stream from the serial port `p`.
  result = SerialStream(
    port: p,
    isBuffered: buffered,
    closeImpl: spClose,
    atEndImpl: spAtEnd,
    setPositionImpl: spSetPosition,
    getPositionImpl: spGetPosition,
    readDataImpl: spReadData,
    peekDataImpl: spPeekData,
    writeDataImpl: spWriteData,
    flushImpl: spFlush,
  )

proc newSerialStream*(portName: string, baudRate: int32, parity: Parity, dataBits: byte, stopBits: StopBits,
                      handshaking: Handshake = Handshake.None, readTimeout = TIMEOUT_INFINITE,
                      writeTimeout = TIMEOUT_INFINITE, dtrEnable = false, rtsEnable = false, buffered = false): SerialStream =
  ## Create a new serial stream for the given serial port with name `portName` and the given settings.
  let port = newSerialPort(portName)
  port.open(baudRate, parity, dataBits, stopBits, handshaking, readTimeout, writeTimeout, dtrEnable, rtsEnable)

  result = newSerialStream(port, buffered)

proc getTimeouts*(stream: SerialStream): tuple[readTimeout: int32, writeTimeout: int32] =
  ## Get the read and write timeouts for the serial port.
  result = stream.port.getTimeouts()

proc setTimeouts*(stream: SerialStream, readTimeout: int32, writeTimeout: int32) =
  ## Set the read and write timeouts for the serial port.
  stream.port.setTimeouts(readTImeout, writeTimeout)

proc isCarrierHolding*(stream: SerialStream): bool =
  ## Check whether the carrier signal is currently active.
  result = stream.port.isCarrierHolding

proc isCtsHolding*(stream: SerialStream): bool =
  ## Check whether the clear to send signal is currently active.
  result = stream.port.isCtsHolding()

proc isDsrHolding*(stream: SerialStream): bool =
  ## Check whether the data set ready signal is currently active.
  result = stream.port.isDsrHolding()

proc isRingHolding*(stream: SerialStream): bool =
  ## Check whether the ring signal is currently active.
  result = stream.port.isRingHolding()

proc `stopBits=`*(stream: SerialStream, stopBits: StopBits) =
  ## Set the stop bits for the serial port.
  stream.port.stopBits = stopBits

proc stopBits*(stream: SerialStream): StopBits =
  ## Get the stop bits for the serial port.
  result = stream.port.stopBits

proc `dataBits=`*(stream: SerialStream, dataBits: byte) =
  ## Set the number of data bits for the serial port.
  stream.port.dataBits = dataBits

proc dataBits*(stream: SerialStream): byte =
  ## Get the number of data bits for the serial port.
  result = stream.port.dataBits

proc `baudRate=`*(stream: SerialStream, baudRate: int32) =
  ## Set the baud rate for the serial port.
  stream.port.baudRate = baudRate

proc baudRate*(stream: SerialStream): int32 =
  ## Get the baud rate for the serial port.
  result = stream.port.baudRate

proc `parity=`*(stream: SerialStream, parity: Parity) =
  ## Set the parity for the serial port.
  stream.port.parity = parity

proc parity*(stream: SerialStream): Parity =
  ## Get the parity for the serial port.
  result = stream.port.parity

proc `breakStatus=`*(stream: SerialStream, shouldBreak: bool) =
  ## Set the break state on the serial port.
  stream.port.breakStatus = shouldBreak

proc breakStatus*(stream: SerialStream): bool =
  ## Get the break state on the serial port.
  result = stream.port.breakStatus

proc `dtrEnable=`*(stream: SerialStream, dtrEnabled: bool) =
  ## Set or clear the data terminal ready signal.
  stream.port.dtrEnable = dtrEnabled

proc dtrEnable*(stream: SerialStream): bool =
  ## Check whether the data terminal ready signal is currently set.
  result = stream.port.dtrEnable

proc `rtsEnable=`*(stream: SerialStream, rtsEnabled: bool) =
  ## Set or clear the ready to send signal.
  stream.port.rtsEnable = rtsEnabled

proc rtsEnable*(stream: SerialStream): bool =
  ## Check whether the ready to send signal is currently set.
  result = stream.port.rtsEnable

proc `handshake=`*(stream: SerialStream, handshake: Handshake) =
  ## Set the handshaking type for the serial port.
  stream.port.handshake = handshake

proc handshake*(stream: SerialStream): Handshake =
  ## Get the handshaking type for the serial port.
  result = stream.port.handshake
