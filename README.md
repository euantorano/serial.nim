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

There are two examples in the `examples` directory, showing reading from and writing to a serialport.

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
  let numReceived = port.read(addr receiveBuffer[0], len(receiveBuffer))
  port.write(addr receiveBuffer[0], numReceived)
```

### Using the SerialStream

```nim
import serial # Or: `import serial/serialstream`

let port = newSerialStream("COM1", 9600, Parity.None, 8, StopBits.One, buffered=true)

while true:
  # Read a line from the serial port then write it back.
  port.writeLine(port.readLine())
```

## Todo List

- [X] Basic port reading/writing for Windows/Posix
    - [X] Posix
    - [X] Windows
- [X] Port setting control - baud rate, stop bits, databits, parity
    - [X] Posix
    - [X] Windows
- [X] Port listing to list available serial ports
    - [X] Windows, using `SetupDiGetClassDevs`
    - [X] Mac, using I/O Kit
    - [X] Posix, by iteratng possible device files
- [X] High level `SerialPortStream` that complies with the `streams` API
- [ ] Async API using `asyncdispatch`
