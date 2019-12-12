# Windows specific code to list available serial ports using SetupDiGetClassDevs().

import windows_registry

iterator listSerialPorts*(): string =
  ## Iterates through a list of serial port names currently available on the system.

  # the SERIALCOMM node does not exist if no serial 
  # devices have been plugged in since bootup hence the 'try'. 
  try:
    for k, v in enumKeyValues(r"HARDWARE\DEVICEMAP\SERIALCOMM", HKEY_LOCAL_MACHINE):
      yield v 
  except OSError:
    discard 

