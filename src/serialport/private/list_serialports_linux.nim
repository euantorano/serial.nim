# Linux specific code to list available serial ports.

import os

const deviceGrepPaths = ["/dev/ttyS*", "/dev/ttyUSB*", "/dev/ttyACM*", "/dev/ttyAMA*", "/dev/rfcomm*"]

proc checkPath(path: string): bool =
  let fileName = extractFilename(path)
  let fullDevicePath = "/sys/class/tty" / filename / "device"

  var subsystem: string = ""

  if symlinkExists(fullDevicePath):
    let devicePath = expandFilename(fullDevicePath)
    subsystem = extractFilename(expandFilename(devicePath / "subsystem"))

    if subsystem != "platform":
      result = true

iterator getPortsForPath(path: string): string {.raises: [OSError].} =
  for f in walkPattern(path):
    if checkPath(f):
      yield f

iterator listSerialPorts*(): string {.raises:[OSError].} =
  for path in deviceGrepPaths:
    for port in getPortsForPath(path):
      yield port
