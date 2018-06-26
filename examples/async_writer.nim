## This example shows writing to a serial port asynchronously.

import serial, sequtils, strutils, streams, asyncdispatch

when isMainModule:
  proc writeLoop(port: AsyncSerialPort): Future[bool] {.async.} =
    result = true

    write(stdout, "Enter data (EXIT to quit): ")
    var toSend = readLine(stdin)

    if toSend == "EXIT":
      return false

    try:
      let numWritten = await port.write(addr toSend[0], int32(len(toSend)))

      echo "Wrote ", numWritten, " bytes to the serial port"
    except:
      echo "Error writing to serial port: ", getCurrentExceptionMsg()
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

    while await writeLoop(serialPort):
      discard

    serialPort.close()

  asyncCheck main()
  runForever()
