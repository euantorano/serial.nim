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

    let serialPort = newSerialStream(portName, 9600, Parity.None, 8, StopBits.One, Handshake.None, buffered=true)
    defer: close(serialPort)

    echo "Opened serial port '", portName, "', ready to send"

    var toSend: string
    while true:
      write(stdout, "Enter data (EXIT to quit): ")
      toSend = readLine(stdin)

      if toSend == "EXIT":
        return

      serialPort.writeLine(toSend)

  main()
