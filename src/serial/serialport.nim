## Methods to open, read from and write to serial ports.

when defined(windows):
  include ./private/serialport/serialport_windows
elif defined(posix):
  include ./private/serialport/serialport_posix
else:
  {.error: "Serial port handling not implemented for your platform".}
