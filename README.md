# serialport.nim

A library to work with serial ports using pure Nim.

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
