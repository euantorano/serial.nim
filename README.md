# serialport.nim

A library to work with serial ports using pure Nim.

## Installation

```
nimble install serialport
```

## Usage

### Reading from a serial port, into a pre-defined buffer:

```nim
import serialport

let port = openSerialPort("COM3",
    baudRate=BaudRate.BR9600, dataBits=DataBits.eight,
    stopBits=StopBits.one, parity=Parity.none,
    useHardwareFlowControl=true, useSoftwareFlowControl=false)

## The baud rate, data bits, stop bits and parity default to 9600, 8, 1 and none - in that order

echo "Opened port: ", $port

echo "Baud rate: ", port.baudRate
echo "Data bits: ", port.dataBits
echo "Parity: ", port.parity
echo "Stop bits: ", port.stopBits
echo "Hardware flow control: ", port.hardwareFlowControl
echo "Software flow control: ", port.softwareFlowControl

var readBuffer = newString(100)
var numRead = port.read(readBuffer[0].addr, len(readBuffer))
echo "Read ", numRead, " bytes from the serial port: ", readBuffer

## You can also set a read timeout, rather than blocking until some data is received:

numRead = port.read(readBuffer[0].addr, len(readBuffer), timeout=5) # Wait for 5 seconds. If no data is received, a `PortTimeoutError` is raised
echo "Read ", numRead, " bytes from the serial port: ", readBuffer
```

### Writing to a serial port:

```nim
import serialport

let port = openSerialPort("COM3",
    baudRate=BaudRate.BR9600, dataBits=DataBits.eight,
    stopBits=StopBits.one, parity=Parity.none,
    useHardwareFlowControl=true, useSoftwareFlowControl=false)

## The baud rate, data bits, stop bits and parity default to 9600, 8, 1 and none - in that order

echo "Opened port: ", $port

echo "Baud rate: ", port.baudRate
echo "Data bits: ", port.dataBits
echo "Parity: ", port.parity
echo "Stop bits: ", port.stopBits
echo "Hardware flow control: ", port.hardwareFlowControl
echo "Software flow control: ", port.softwareFlowControl

## The below will write as much data as it can
var dataToSend = "Hello, World!"
var numWritten = port.write(dataToSend[0].addr, len(dataToSend))
echo "Wrote ", numWritten, " bytes to the serial port"

## Rather than working with pointers, there are also convenience methods that have timeouts:
let newDataToSend = "This is a test"
port.write(newDataToSend, timeout=5) # Wait for 5 seconds. If the data isn't transmitted in time, a `PortTimeoutError` is raised
# This will also guarantee that all of the data is written, unless an error occurs
```

### Listing serial ports available on the system

```nim
import serialport

for p in listSerialPorts():
  echo "Found serial port: ", p
```

## Todo List

- [X] Basic port reading/writing for Windows/Posix
    - [X] Posix
    - [X] Windows
- [X] Port setting control - baud rate, stop bits, databits, parity
    - [X] Posix
    - [X] Windows
- [ ] Port listing to list available serial ports
    - [X] Windows, using `SetupDiGetClassDevs`
    - [X] Mac, using I/O Kit
    - [ ] Posix, by iteratng possible device files
- [ ] High level `SerialPortStream` that complies with the `streams` API.
