import libserialport, os

const
  writePort: string = "/dev/cu.usbserial-FTZ9WDJA"
    ## Change the above port to match a serial port available on your system.

when isMainModule:
  proc main() =
    let writer = openSerialPort(writePort, useHardwareFlowControl=true)
    defer: close(writer)

    echo "Baud rate: ", writer.baudRate
    echo "Data bits: ", writer.dataBits
    echo "Parity: ", writer.parity
    echo "Stop bits: ", writer.stopBits
    echo "Hardware flow control: ", writer.hardwareFlowControl
    echo "Software flow control: ", writer.softwareFlowControl

    var rawWriteData = "Hello World!\n"

    echo "Wrote ", writer.write(rawWriteData[0].addr, len(rawWriteData)), " bytes to the serial port"

    writer.write("All of this data is assured to be written unless an error occurs.")

    echo "Starting read..."
    var data: string = newString(100)
    let numRead = writer.read(data[0].addr, len(data))
    echo "Read ", numRead, " bytes from the serial port: ", data

  main()
