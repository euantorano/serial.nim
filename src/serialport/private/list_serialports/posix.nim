# Code to list available serial ports on various POSIX systems.

import os

when defined(openbsd):
  const supportedPlatform = true
  const serialDevicesPattern = "/dev/cua*"
elif defined(freebsd):
  const supportedPlatform = true
  const serialDevicesPattern = "/dev/cua*[!.init][!.lock]"
elif defined(netbsd):
  const supportedPlatform = true
  const serialDevicesPattern = "/dev/dty*"
else:
  const supportedPlatform = false
  {.warning: "Unknown platform, listing serial ports is not supported.".}

when supportedPlatform:
  iterator listSerialPorts*(): string {.raises:[OSError].} =
    for p in walkPattern(serialDevicesPattern):
      yield p
else:
  iterator listSerialPorts*(): string {.raises:[OSError].} = discard
