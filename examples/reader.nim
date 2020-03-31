## This example shows reading from a serial port.

import serial, sequtils, strutils, streams

when isMainModule:
  proc main() =
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

    let serialPort = newSerialStream(portName, 9600, Parity.None, 8, StopBits.One, Handshake.None, buffered=false)
    defer: close(serialPort)

    serialPort.setTimeouts(5000, 500)

    echo "Opened serial port '", portName, "', receiving"

    while true:
      let ln = serialPort.readLine()

      echo "Received: '", ln, "'"

  main()
