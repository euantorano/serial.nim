## This example shows reading from a serial port asynchronously.

import serial, sequtils, strutils, streams, asyncdispatch

when isMainModule:
  proc readLoop(port: AsyncSerialPort): Future[bool] {.async.} =
    result = true

    let futVar = newFutureVar[string]()
    futVar.mget() = newString(10)

    try:
      discard await port.read(futVar)

      echo "Received from the serial port: ", futVar.read()
    except:
      echo "Error reading from serial port: ", getCurrentExceptionMsg()
      result = false

  proc main() {.async.} =
    let serialPorts = toSeq(listSerialPorts())

    echo "Serial Ports"
    echo "------------"

    for i in low(serialPorts)..high(serialPorts):
      echo "[", i, "] ", serialPorts[i]

    echo ""
    var portName: string

    while true:
      write(stdout, "Select port: ")

      try:
        let num = parseInt(readLine(stdin))
        portName = serialPorts[num]

        break
      except:
        writeLine(stderr, "[ERROR] Invalid port")

    let serialPort = newAsyncSerialPort(portName)
    serialPort.open(9600, Parity.None, 8, StopBits.One, Handshake.None)

    while await readLoop(serialPort):
      discard

    serialPort.close()

  asyncCheck main()
  runForever()
