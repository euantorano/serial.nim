# Linux specific code to list available serial ports.

import os

const deviceGrepPaths = ["dev/ttyS*", "/dev/ttyUSB*", "/dev/ttyACM*", "/dev/ttyAMA*", "/dev/rfcomm*"]

proc checkPath(path: string): bool = false

iterator getPortsForPath(path: string): string {.raises: [OSError].} =
  for f in walkFiles(path):
    echo "Path: ", f
    if checkPath(f):
      yield f

iterator listSerialPorts*(): string {.raises:[OSError].} =
  for path in deviceGrepPaths:
    for port in getPortsForPath(path):
      yield port
