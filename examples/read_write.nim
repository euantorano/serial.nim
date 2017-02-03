import serialport, os

const
  writePort: string = "/dev/cu.usbserial-FTZ9WGKP"
    ## Change the above port to match a serial port available on your system.

when isMainModule:
  proc main() =
    let writer = openSerialPort(writePort)
    defer: close(writer)

    writer.baudRate = BaudRate.BR9600
    doAssert(writer.baudRate == BaudRate.BR9600, "Baud rates don't match")
    writer.dataBits = DataBits.eight
    doAssert(writer.dataBits == DataBits.eight, "Data bits don't match")
    writer.parity = Parity.none
    doAssert(writer.parity == Parity.none, "Parities don't match")
    writer.stopBits = StopBits.one
    doAssert(writer.stopBits == StopBits.one, "Stop bits don't match")

    writer.write("Hiya")

    # TODO: hack to wait for the data to be written. Can we make the `write()` block?
    sleep(500)

  main()
