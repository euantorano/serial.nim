## This example shows both reading from and writing to a serialport asynchronously.
##
## Note that it may not seem like anything is being received until you send some data - this is because the `readLine()` to read data from the input blocks the application.
##
## In a real application, you would have to get around this by reading input asynchronously too.

import serial, sequtils, strutils, streams, asyncdispatch

when isMainModule:
  proc readLoop(port: AsyncSerialPort) {.async.} =
    var
      buff = newString(1024)
      numReceived: int32

    while port.isOpen():
      numReceived = await port.read(addr buff[0], int32(len(buff)))

      echo "Received: ", buff[0 ..< numReceived]

  proc writeLoop(port: AsyncSerialPort) {.async.} =
    while port.isOpen():
      write(stdout, "Enter data (EXIT to quit): ")
      var toSend = readLine(stdin)

      if toSend == "EXIT":
        break

      discard await port.write(toSend)

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

    let
      readTask = readLoop(serialPort)
      writeTask = writeLoop(serialPort)

    await readTask or writetask

    serialPort.close()

  asyncCheck main()
  runForever()
