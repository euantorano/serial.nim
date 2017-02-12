# Linux specific code to list available serial ports.

import os

const deviceGrepPaths = ["/dev/ttyS*", "/dev/ttyUSB*", "/dev/ttyACM*", "/dev/ttyAMA*", "/dev/rfcomm*"]

proc checkPath(path: string): bool =
  let fileName = extractFilename(path)
  let fullDevicePath = "/sys/class/tty" / filename / "device"

  var devicePath: string = "",
    subsystem: string = ""

  if existsFile(fullDevicePath):
    devicePath = expandFilename(fullDevicePath)
    subsystem = extractFilename(expandFilename("/sys/class/tty" / filename / "subsystem"))
  else:
    devicePath = ""

  if subsystem != "platform":
    result = true

  echo "Got subsystem '", subsystem, "' device path: ", devicePath, " for file: ", path


iterator getPortsForPath(path: string): string {.raises: [OSError].} =
  for f in walkPattern(path):
    echo "Path: ", f
    if checkPath(f):
      yield f

iterator listSerialPorts*(): string {.raises:[OSError].} =
  for path in deviceGrepPaths:
    for port in getPortsForPath(path):
      yield port
