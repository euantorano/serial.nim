when defined(nimdoc):
  iterator listSerialPorts*(): string {.raises: [OSError].} = discard
    ## Iterate through a list of the available serial port names on the system.
elif defined(windows):
  include ./private/utils/list_serialports_windows
elif defined(macosx):
  include ./private/utils/list_serialports_mac
elif defined(linux):
  include ./private/utils/list_serialports_linux
elif defined(posix) or defined(nuttx):
  include ./private/utils/list_serialports_posix
else:
  {.warning: "Unknown platform, listing serial ports is not supported.".}
