{.deadCodeElim:on.}

when defined(nimdoc):
  iterator listSerialPorts*(): string {.raises:[OSError].} = discard
    ## Iterate through a list of the available serial port names on the system.
elif defined(windows):
  include ./list_serialports/windows
elif defined(macosx):
  include ./list_serialports/mac
elif defined(linux):
  include ./list_serialports/linux
elif defined(posix):
  include ./list_serialports/posix
else:
  {.warning: "Unknown platform, listing serial ports is not supported.".}
