{.deadCodeElim:on.}

iterator listSerialPorts*(): string = discard
  ## Iterates through a list of serial port names currently available on the system.

when defined(windows):
  include ./list_serialports_win
  # TODO: OS X specific version (using devicekit), posix versions
else:
  {.error: "Unsupported OS".}
