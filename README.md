# serial.nim

A library to work with serial ports using pure Nim.

## Installation

`serial` can be installed using Nimble:

```
nimble install serial
```

Or add the following to your .nimble file:

```
# Dependencies

requires "serial >= 1.0.0"
```

## [API Documentation](https://htmlpreview.github.io/?https://github.com/euantorano/serial.nim/blob/master/docs/serial.html)

## Usage

There are some examples in the `examples` directory, showing reading from and writing to a serialport.

### Listing serial ports

```nim
import serial # Or: `import serial/utils`

for port in listSerialPorts():
  echo port
```

### Reading from/writing to a serial port (echoing data)

```nim
import serial # Or: `import serial/serialport`

let port = newSerialPort("COM1")
# use 9600bps, no parity, 8 data bits and 1 stop bit
port.open(9600, Parity.None, 8, StopBits.One)

# You can modify the baud rate, parity, databits, etc. after opening the port
port.baudRate = 2400

var receiveBuffer = newString(1024)
while true:
  let numReceived = port.read(receiveBuffer)
  discard port.write(receiveBuffer[0 ..< numReceived])
```

### Using the SerialStream

```nim
import serial # Or: `import serial/serialstream`

let port = newSerialStream("COM1", 9600, Parity.None, 8, StopBits.One, buffered=true)

while true:
  # Read a line from the serial port then write it back.
  port.writeLine(port.readLine())
```

## Features

- Basic port reading/writing for Windows/Posix
- Port setting control - baud rate, stop bits, databits, parity, handshaking
- Port listing to list available serial ports
    - Windows, using `SetupDiGetClassDevs`
    - Mac, using I/O Kit
    - Posix, by iterating possible device files
- High level `SerialPortStream` that complies with the `streams` API
- Async API using `asyncdispatch` for reading from and writing to a port
