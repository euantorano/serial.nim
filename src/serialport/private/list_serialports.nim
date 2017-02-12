{.deadCodeElim:on.}

when defined(nimdoc):
  iterator listSerialPorts*(): string {.raises:[OSError].} = discard
    ## Iterate through a list of the available serial port names on the system.
elif defined(windows):
  include ./list_serialports_win
elif defined(macosx):
  include ./list_serialports_mac
else:
  {.error: "Unsupported OS".}
