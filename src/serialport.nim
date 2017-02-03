## A library to work with serial ports using pure Nim.

include serialport/private/list_serialports

when defined(posix):
  include serialport/private/serial_posix
