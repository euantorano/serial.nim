{.deadCodeElim:on.}

when defined(windows):
  include ./list_serialports_win
  # TODO: OS X specific version (using devicekit), posix versions
else:
  {.error: "Unsupported OS".}
