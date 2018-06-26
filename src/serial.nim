## Serialport library for Nim that allows the reading from and writing to serial ports conencted to the system.
##
## This module exports several submodules:
## - `serialport` - key serialport handling logic, letting you open and manage serial ports.
## - `serialstream` - a Stream type for reading from and writing to a serial port.
## - `utils` - a utility module that lets you list all of the available serial ports on the system.
##
## Usage
## ===============
##
## Listing serial ports
## -----------------
##
## .. code-block:: Nim
##  import serial # Or: `import serial/utils`
##
##  for port in listSerialPorts():
##    echo port
##
## Reading from/writing to a serial port (echoing data)
## -----------------
##
## .. code-block:: Nim
##  import serial # Or: `import serial/serialport`
##
##  let port = newSerialPort("COM1")
##  # use 9600bps, no parity, 8 data bits and 1 stop bit
##  port.open(9600, Parity.None, 8, StopBits.One)
##
##  # You can modify the baud rate, parity, databits, etc. after opening the port
##  port.baudRate = 2400
##
##  var receiveBuffer = newString(1024)
##  while true:
##    let numReceived = port.read(receiveBuffer)
##    discard port.write(receiveBuffer[0 ..< numReceived])
##
## Using the SerialStream
## -----------------
##
## The `SerialStream` type implements the `Stream` interface from the `streams` module. It also optionally buffers received data.
##
## .. code-block:: Nim
##  import serial # Or: `import serial/serialstream`
##
##  let port = newSerialStream("COM1", 9600, Parity.None, 8, StopBits.One,
##                             buffered=true)
##
##  while true:
##    # Read a line from the serial port then write it back.
##    port.writeLine(port.readLine())

import streams

import serial/serialport, serial/serialstream, serial/utils
export serialport, serialstream, utils

when isMainModule:
  echo "Available Serial Ports"
  echo "----------------------"
  for port in listSerialPorts():
    echo port

  echo ""

  let port = newSerialPort("COM5")
  port.open(38400, Parity.None, 8, StopBits.One, readTimeout = 5000, writeTimeout = 1000)

  echo "Opened port COM5"

  echo "Baud Rate: ", port.baudRate
  echo "Parity: ", port.parity
  echo "Data Bits: ", port.dataBits
  echo "Stop Bits: ", port.stopBits
  echo "Handshaking: ", port.handshake

  echo "Carrier holding? ", port.isCarrierHolding
  echo "CTS holding? ", port.isCtsHolding
  echo "DSR holding? ", port.isDsrHolding
  echo "Ring holding? ", port.isRingHolding
  echo "RTS? ", port.rtsEnable
  echo "DTR? ", port.dtrEnable
  echo "Break? ", port.breakStatus

  let (readTimeout, writeTimeout) = port.getTimeouts()
  echo "Read timeout: ", readTimeout
  echo "Write timeout: ", writeTimeout

  var writeBuff = "Hello, World\n"
  let numWritten = port.write(addr writeBuff[0], int32(len(writeBuff)))

  echo "Wrote ", numWritten, " bytes: ", writeBuff[0..numWritten]

  var buff: string = newString(1024)
  let numRead = port.read(addr buff[0], int32(len(buff)))

  echo "Read ", numRead, " bytes: ", buff[0..numRead]

  port.close()

  echo "Closed port COM5"

  echo "Using stream"

  let portStream = newSerialStream("COM5", 38400, Parity.None, 8, StopBits.One, buffered=true)
  echo "Opened COM5 using stream"

  portStream.writeLine("AT")

  for i in 0..1:
    echo "Received line from stream: ", portStream.readLine()

  portStream.close()
